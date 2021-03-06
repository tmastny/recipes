#' Apply (Smoothed) Rectified Linear Transformation
#'
#' `step_relu` creates a *specification* of a recipe step that
#'   will apply the rectified linear or softplus transformations to numeric
#'   data. The transformed data is added as new columns to the data matrix.
#'
#' @inheritParams step_center
#' @param recipe A recipe object. The step will be added to the sequence of
#'   operations for this recipe.
#' @param ... One or more selector functions to choose which variables are
#'   affected by the step. See [selections()] for more details.
#' @param role Defaults to "predictor".
#' @param trained A logical to indicate if the quantities for preprocessing
#'   have been estimated.
#' @param shift A numeric value dictating a translation to apply to the data.
#' @param reverse A logical to indicate if the left hinge should be used as
#'   opposed to the right hinge.
#' @param smooth A logical indicating if the softplus function, a smooth
#'   approximation to the rectified linear transformation, should be used.
#' @param prefix A prefix for generated column names, default to "right_relu_"
#'   when right hinge transformation and "left_relu_" for reversed/left hinge
#'   transformations.
#' @param columns A character string of variable names that will
#'  be populated (eventually) by the `terms` argument.
#' @return An updated version of `recipe` with the
#'   new step added to the sequence of existing steps (if any).
#' @export
#' @rdname step_relu
#'
#' @details The rectified linear transformation is calculated as
#'   \deqn{max(0, x - c)} and is also known as the ReLu or right hinge function.
#'   If `reverse` is true, then the transformation is reflected about the
#'   y-axis, like so: \deqn{max(0, c - x)} Setting the `smooth` option
#'   to true will instead calculate a smooth approximation to ReLu
#'   according to \deqn{ln(1 + e^(x - c)} The `reverse` argument may
#'   also be applied to this transformation.
#'
#' @section Connection to MARS:
#'
#' The rectified linear transformation is used in Multivariate Adaptive
#' Regression Splines as a basis function to fit piecewise linear functions to
#' data in a strategy similar to that employed in tree based models. The
#' transformation is a popular choice as an activation function in many
#' neural networks, which could then be seen as a stacked generalization of
#' MARS when making use of ReLu activations. The hinge function also appears
#' in the loss function of Support Vector Machines, where it penalizes
#' residuals only if they are within a certain margin of the decision boundary.
#'
#' @examples
#' library(modeldata)
#' data(biomass)
#'
#' biomass_tr <- biomass[biomass$dataset == "Training",]
#' biomass_te <- biomass[biomass$dataset == "Testing",]
#'
#' rec <- recipe(HHV ~ carbon + hydrogen + oxygen + nitrogen + sulfur,
#'               data = biomass_tr)
#'
#' transformed_te <- rec %>%
#'   step_relu(carbon, shift = 40) %>%
#'   prep(biomass_tr) %>%
#'   bake(biomass_te)
#'
#' transformed_te
#'
#' @seealso [recipe()] [prep.recipe()]
#'   [bake.recipe()]
step_relu <-
  function(recipe,
           ...,
           role = "predictor",
           trained = FALSE,
           shift = 0,
           reverse = FALSE,
           smooth = FALSE,
           prefix = "right_relu_",
           columns = NULL,
           skip = FALSE,
           id = rand_id("relu")) {
    if (!is_tune(shift) & !is_varying(shift)) {
      if (!is.numeric(shift)) {
        rlang::abort("Shift argument must be a numeric value.")
      }
    }
    if (!is_tune(reverse) & !is_varying(reverse)) {
      if (!is.logical(reverse)) {
        rlang::abort("Reverse argument must be a logical value.")
      }
    }
    if (!is_tune(smooth) & !is_varying(smooth)) {
      if (!is.logical(smooth)) {
        rlang::abort("Smooth argument must be logical value.")
      }
    }
    if (reverse & prefix == "right_relu_") {
      prefix <- "left_relu_"
    }
    add_step(
      recipe,
      step_relu_new(
        terms = ellipse_check(...),
        role = role,
        trained = trained,
        shift = shift,
        reverse = reverse,
        smooth = smooth,
        prefix = prefix,
        columns = columns,
        skip = skip,
        id = id
      )
    )
  }

step_relu_new <-
  function(terms, role, trained, shift, reverse, smooth, prefix, columns, skip, id) {
    step(
      subclass = "relu",
      terms = terms,
      role = role,
      trained = trained,
      shift = shift,
      reverse = reverse,
      smooth = smooth,
      prefix = prefix,
      columns = columns,
      skip = skip,
      id = id
    )
  }

#' @export
prep.step_relu <- function(x, training, info = NULL, ...) {
  columns <- terms_select(x$terms, info = info)
  check_type(training[, columns])

  step_relu_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    shift = x$shift,
    reverse = x$reverse,
    smooth = x$smooth,
    prefix = x$prefix,
    columns = columns,
    skip = x$skip,
    id = x$id
  )
}

#' @export
bake.step_relu <- function(object, new_data, ...) {
  make_relu_call <- function(col) {
    call2("relu", sym(col), object$shift, object$reverse, object$smooth)
  }
  exprs <- purrr::map(object$columns, make_relu_call)
  newname <- paste0(object$prefix, object$columns)
  exprs <- check_name(exprs, new_data, object, newname, TRUE)
  dplyr::mutate(new_data, !!!exprs)
}


print.step_relu <-
  function(x, width = max(20, options()$width - 30), ...) {
    cat("Adding relu transform for ", sep = "")
    cat(format_selectors(x$terms, width = width))
    if (x$trained)
      cat(" [trained]\n")
    else
      cat("\n")
    invisible(x)
}


relu <- function(x, shift = 0, reverse = FALSE, smooth = FALSE) {
  if (!is.numeric(x))
    rlang::abort("step_relu can only be applied to numeric data.")

  if (reverse) {
    shifted <- shift - x
  } else {
    shifted <- x - shift
  }

  if (smooth) {
    out <- log1p(exp(shifted))  # use log1p for numerical accuracy
  } else {
    out <- pmax(shifted, rep(0, length(shifted)))
  }
  out
}

#' @rdname step_relu
#' @param x A `step_relu` object.
#' @export
tidy.step_relu <- function(x, ...) {
  out <- simple_terms(x, ...)
  out$shift <- x$shift
  out$reverse <- x$reverse
  out$id <- x$id
  out
}
