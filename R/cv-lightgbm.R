#' lightgbm - parameter tuning and model selection with k-fold cross-validation and grid search
#'
#' @param x Predictor matrix
#' @param y Response vector
#' @param nfolds Number of folds. Default is 5.
#' @param seed Random seed for reproducibility
#' @param verbose Show progress?
#' @param num_iterations Grid vector for the parameter \code{num_iterations}.
#' @param max_depth Grid vector for the parameter \code{max_depth}.
#' @param learning_rate Grid vector for the parameter \code{learning_rate}.
#' @param ncpus Number of CPU cores to use. Defaults is all detectable cores.
#'
#' @return A data frame containing the complete tuning grid and the AUC values,
#' with the best parameter combination and the highest AUC value.
#'
#' @export cv_lightgbm
#'
#' @examples
#' # check the vignette for code examples
cv_lightgbm <- function(
  x, y, nfolds = 5L, seed = 42, verbose = TRUE,
  num_iterations = c(10, 50, 100, 200, 500, 1000),
  max_depth = c(2, 3, 4, 5),
  learning_rate = c(0.001, 0.01, 0.02, 0.05, 0.1),
  ncpus = parallel::detectCores()) {
  set.seed(seed)
  nrow_x <- nrow(x)
  index <- sample(rep_len(1L:nfolds, nrow_x))
  df_grid <- expand.grid(
    "num_iterations" = num_iterations,
    "max_depth" = max_depth,
    "learning_rate" = learning_rate,
    "metric" = NA
  )
  nrow_grid <- nrow(df_grid)

  x <- as.matrix(x)

  pb <- progress_bar$new(
    format = "  searching grid [:bar] :percent in :elapsed",
    total = nrow_grid * nfolds, clear = FALSE, width = 60
  )

  for (j in 1L:nrow_grid) {
    ypred <- matrix(NA, ncol = 2L, nrow = nrow_x)
    for (i in 1L:nfolds) {
      if (verbose) pb$tick()

      xtrain <- x[index != i, , drop = FALSE]
      ytrain <- y[index != i]
      xtest <- x[index == i, , drop = FALSE]
      ytest <- y[index == i]

      fit <- lightgbm(
        data = xtrain,
        label = ytrain,
        objective = "binary",
        learning_rate = df_grid[j, "learning_rate"],
        num_iterations = df_grid[j, "num_iterations"],
        max_depth = df_grid[j, "max_depth"],
        num_leaves = 2^(df_grid[j, "max_depth"]) - 1,
        verbose = -1,
        num_threads = ncpus
      )
      ypredvec <- predict(fit, xtest)
      ypred[index == i, 1L] <- ytest
      ypred[index == i, 2L] <- ypredvec
    }
    colnames(ypred) <- c("y.real", "y.pred")
    df_grid[j, "metric"] <- as.numeric(pROC::auc(ypred[, "y.real"], ypred[, "y.pred"], quiet = TRUE))
  }

  best_row <- which.max(df_grid$metric)
  best_metric <- df_grid$metric[best_row]
  best_num_iterations <- df_grid$num_iterations[best_row]
  best_max_depth <- df_grid$max_depth[best_row]
  best_learning_rate <- df_grid$learning_rate[best_row]

  list(
    df = df_grid,
    metric = best_metric,
    num_iterations = best_num_iterations,
    max_depth = best_max_depth,
    learning_rate = best_learning_rate
  )
}
