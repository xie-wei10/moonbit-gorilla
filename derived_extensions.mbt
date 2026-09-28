///|
pub extend BlockInfo with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BlockInfo with Eq::{not_equal, equal}

///|
pub extend CodecError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Sample with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Sample with Eq::{not_equal, equal}
