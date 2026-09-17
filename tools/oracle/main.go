// Independent executable adapter. All XOR encoding/decoding is performed by the
// unmodified, version-pinned Prometheus chunkenc package.
package main

import (
	"bufio"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"github.com/prometheus/prometheus/tsdb/chunkenc"
	"math"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"time"
)

type sample struct {
	Timestamp string `json:"timestamp"`
	Bits      string `json:"bits"`
}
type rawSample struct {
	t    int64
	bits uint64
}
type request struct {
	Operation   string   `json:"operation"`
	Samples     []sample `json:"samples"`
	Hex         string   `json:"hex"`
	Repeats     int      `json:"repeats"`
	OmitSamples bool     `json:"omitSamples"`
}
type response struct {
	OK       bool     `json:"ok"`
	Error    string   `json:"error,omitempty"`
	Hex      string   `json:"hex,omitempty"`
	Samples  []sample `json:"samples,omitempty"`
	EncodeNs int64    `json:"encodeNs,omitempty"`
	DecodeNs int64    `json:"decodeNs,omitempty"`
	Runtime  string   `json:"runtime"`
	Module   string   `json:"module"`
}

func run(r request) (out response) {
	out.Runtime = runtime.Version()
	if info, ok := debug.ReadBuildInfo(); ok {
		for _, dep := range info.Deps {
			if dep.Path == "github.com/prometheus/prometheus" {
				out.Module = dep.Path + "@" + dep.Version
			}
		}
	}
	defer func() {
		if failure := recover(); failure != nil {
			out.OK = false
			out.Error = fmt.Sprint(failure)
		}
	}()
	repeats := r.Repeats
	if repeats < 1 {
		repeats = 1
	}
	if repeats > 100 {
		panic("repeat limit")
	}
	var data []byte
	if r.Operation == "decode" {
		var err error
		data, err = hex.DecodeString(r.Hex)
		if err != nil {
			panic(err)
		}
	} else {
		if len(r.Samples) > 65535 {
			panic("sample limit")
		}
		times := make([]int64, len(r.Samples))
		values := make([]float64, len(r.Samples))
		for i, s := range r.Samples {
			t, err := strconv.ParseInt(s.Timestamp, 10, 64)
			if err != nil {
				panic(err)
			}
			b, err := strconv.ParseUint(s.Bits, 10, 64)
			if err != nil {
				panic(err)
			}
			times[i] = t
			values[i] = math.Float64frombits(b)
		}
		start := time.Now()
		for repeat := 0; repeat < repeats; repeat++ {
			chunk := chunkenc.NewXORChunk()
			app, err := chunk.Appender()
			if err != nil {
				panic(err)
			}
			for i, t := range times {
				app.Append(0, t, values[i])
			}
			data = chunk.Bytes()
		}
		out.EncodeNs = time.Since(start).Nanoseconds() / int64(repeats)
	}
	if len(data) < 2 || len(data) > 2000000 {
		panic("chunk byte limit")
	}
	start := time.Now()
	var decoded []rawSample
	for repeat := 0; repeat < repeats; repeat++ {
		chunk, err := chunkenc.FromData(chunkenc.EncXOR, data)
		if err != nil {
			panic(err)
		}
		it := chunk.Iterator(nil)
		decoded = []rawSample{}
		for it.Next() == chunkenc.ValFloat {
			t, v := it.At()
			decoded = append(decoded, rawSample{t, math.Float64bits(v)})
		}
		if err := it.Err(); err != nil {
			panic(err)
		}
	}
	out.DecodeNs = time.Since(start).Nanoseconds() / int64(repeats)
	if !r.OmitSamples {
		for _, s := range decoded {
			out.Samples = append(out.Samples, sample{strconv.FormatInt(s.t, 10), strconv.FormatUint(s.bits, 10)})
		}
	}
	out.Hex = hex.EncodeToString(data)
	out.OK = true
	return
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 65536), 16000000)
	writer := json.NewEncoder(os.Stdout)
	for scanner.Scan() {
		var r request
		if err := json.Unmarshal(scanner.Bytes(), &r); err != nil {
			writer.Encode(response{Error: err.Error()})
			continue
		}
		writer.Encode(run(r))
	}
	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
