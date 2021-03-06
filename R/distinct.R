#' Select distinct/unique rows
#'
#' Retain only unique/distinct rows from an input tbl. This is similar
#' to [unique.data.frame()], but considerably faster.
#'
#' @param .data a tbl
#' @param ... Optional variables to use when determining uniqueness. If there
#'   are multiple rows for a given combination of inputs, only the first
#'   row will be preserved. If omitted, will use all variables.
#' @param .keep_all If `TRUE`, keep all variables in `.data`.
#'   If a combination of `...` is not distinct, this keeps the
#'   first row of values.
#' @inheritParams filter
#' @export
#' @examples
#' df <- tibble(
#'   x = sample(10, 100, rep = TRUE),
#'   y = sample(10, 100, rep = TRUE)
#' )
#' nrow(df)
#' nrow(distinct(df))
#' nrow(distinct(df, x, y))
#'
#' distinct(df, x)
#' distinct(df, y)
#'
#' # Can choose to keep all other variables as well
#' distinct(df, x, .keep_all = TRUE)
#' distinct(df, y, .keep_all = TRUE)
#'
#' # You can also use distinct on computed variables
#' distinct(df, diff = abs(x - y))
#'
#' # The same behaviour applies for grouped data frames
#' # except that the grouping variables are always included
#' df <- tibble(
#'   g = c(1, 1, 2, 2),
#'   x = c(1, 1, 2, 1)
#' ) %>% group_by(g)
#' df %>% distinct()
#' df %>% distinct(x)
distinct <- function(.data, ..., .keep_all = FALSE) {
  UseMethod("distinct")
}
#' @export
distinct.default <- function(.data, ..., .keep_all = FALSE) {
  distinct_(.data, .dots = compat_as_lazy_dots(...), .keep_all = .keep_all)
}
#' @export
#' @rdname se-deprecated
#' @inheritParams distinct
distinct_ <- function(.data, ..., .dots, .keep_all = FALSE) {
  UseMethod("distinct_")
}

#' Same basic philosophy as group_by: lazy_dots comes in, list of data and
#' vars (character vector) comes out.
#' @noRd
distinct_vars <- function(.data, vars, group_vars = character(), .keep_all = FALSE) {
  stopifnot(is_quosures(vars), is.character(group_vars))

  # If no input, keep all variables
  if (length(vars) == 0) {
    list_cols_error(.data, names(.data))
    return(list(
      data = .data,
      vars = names(.data),
      keep = names(.data)
    ))
  }

  # If any calls, use mutate to add new columns, then distinct on those
  .data <- add_computed_columns(.data, vars)

  # Once we've done the mutate, we need to name all objects
  vars <- exprs_auto_name(vars, printer = tidy_text)
  out_vars <- intersect(names(.data), c(names(vars), group_vars))

  if (.keep_all) {
    keep <- names(.data)
  } else {
    keep <- unique(out_vars)
  }

  list_cols_error(.data, keep)
  list(data = .data, vars = out_vars, keep = keep)
}

#' Throw an error if there are tbl columns of type list
#'
#' @noRd
list_cols_error <- function(df, keep_cols) {
  if (any(map_lgl(df[keep_cols], is.list))) {
    abort("distinct() does not support columns of type `list`")
  }
}

#' Efficiently count the number of unique values in a set of vector
#'
#' This is a faster and more concise equivalent of `length(unique(x))`
#'
#' @param \dots vectors of values
#' @param na.rm if `TRUE` missing values don't count
#' @examples
#' x <- sample(1:10, 1e5, rep = TRUE)
#' length(unique(x))
#' n_distinct(x)
#' @export
n_distinct <- function(..., na.rm = FALSE) {
  n_distinct_multi(list(...), na.rm)
}
