#' emMixRHLP is used to fit a MixRHLP model.
#'
#' emMixRHLP is used to fit a MixRHLP model. The estimation method is performed
#' by the Expectation-Maximization algorithm.
#'
#' @details emMixRHLP function implements the EM algorithm. This function starts
#'   with an initialization of the parameters done by the method `initParam` of
#'   the class [ParamMixRHLP][ParamMixRHLP], then it alternates between the
#'   E-Step (method of the class [StatMixRHLP][StatMixRHLP]) and the M-Step
#'   (method of the class [ParamMixRHLP][ParamMixRHLP]) until convergence (until
#'   the relative variation of log-likelihood between two steps of the EM
#'   algorithm is less than the `threshold` parameter).
#'
#' @param X Numeric vector of length \emph{m} representing the covariates/inputs
#'   \eqn{x_{1},\dots,x_{m}}.
#' @param Y Matrix of size \eqn{(n, m)} representing the observed
#'   responses/outputs. `Y` consists of \emph{n} functions of `X` observed at
#'   points \eqn{1,\dots,m}.
#' @param G The number of clusters (Number of RHLP models).
#' @param K The number of regimes (RHLP components) for each cluster.
#' @param p Optional. The order of the polynomial regression. By default, `p` is
#'   set at 3.
#' @param q Optional. The dimension of the logistic regression. For the purpose
#'   of segmentation, it must be set to 1 (which is the default value).
#' @param variance_type Optional character indicating if the model is
#'   "homoskedastic" or "heteroskedastic". By default the model is
#'   "heteroskedastic".
#' @param init_kmeans Optional. A logical indicating whether or not the curve
#'   partition should be initialized by the K-means algorithm. Otherwise the
#'   curve partition is initialized randomly.
#' @param n_tries Optional. Number of runs of the EM algorithm. The solution
#'   providing the highest log-likelihood will be returned.
#'
#'   If `n_tries` > 1, then for the first run, parameters are initialized by
#'   uniformly segmenting the data into K segments, and for the next runs,
#'   parameters are initialized by randomly segmenting the data into K
#'   contiguous segments.
#' @param max_iter Optional. The maximum number of iterations for the EM
#'   algorithm.
#' @param threshold Optional. A numeric value specifying the threshold for the
#'   relative difference of log-likelihood between two steps of the EM as
#'   stopping criteria.
#' @param verbose Optional. A logical value indicating whether or not values of
#'   the log-likelihood should be printed during EM iterations.
#' @param verbose_IRLS Optional. A logical value indicating whether or not
#'   values of the criterion optimized by IRLS should be printed at each step of
#'   the EM algorithm.
#' @return EM returns an object of class [ModelMixRHLP][ModelMixRHLP].
#' @seealso [ModelMixRHLP], [ParamMixRHLP], [StatMixRHLP]
#' @export
emMixRHLP <- function(X, Y, G, K, p = 3, q = 1, variance_type = c("heteroskedastic", "homoskedastic"), init_kmeans = TRUE, n_tries = 1, max_iter = 1000, threshold = 1e-5, verbose = FALSE, verbose_IRLS = FALSE) {

  fData <- FData(X, Y)

  top <- 0
  try_EM <- 0
  best_loglik <- -Inf

  while (try_EM < n_tries) {
    try_EM <- try_EM + 1
    if (n_tries > 1 && verbose) {
      cat(paste0("EM try number: ", try_EM, "\n\n"))
    }

    # Initialization
    variance_type <- match.arg(variance_type)
    param <- ParamMixRHLP$new(fData = fData, G = G, K = K, p = p, q = q, variance_type = variance_type)
    param$initParam(init_kmeans, try_EM)

    iter <- 0
    converge <- FALSE
    prev_loglik <- -Inf

    stat <- StatMixRHLP(param)

    while (!converge && (iter <= max_iter)) {
      stat$EStep(param)

      param$MStep(stat, verbose_IRLS)

      iter <- iter + 1
      if (verbose) {
        cat(paste0("EM: Iteration : ", iter, " || log-likelihood : "  , stat$loglik, "\n"))
      }

      if (prev_loglik - stat$loglik > 1e-5) {
        warning(paste0("EM log-likelihood is decreasing from ", prev_loglik, "to ", stat$loglik, " !"))
        top <- top + 1
        if (top > 20) {
          break
        }
      }

      # Test of convergence
      converge <- abs((stat$loglik - prev_loglik) / prev_loglik) <= threshold
      if (is.na(converge)) {
        converge <- FALSE
      }

      prev_loglik <- stat$loglik
      stat$stored_loglik[iter] <- stat$loglik
    } # End of EM loop

    if (stat$loglik > best_loglik) {
      statSolution <- stat$copy()
      paramSolution <- param$copy()
      best_loglik <- stat$loglik
    }

    if (n_tries > 1 && verbose) {
      cat(paste0("Max value of the log-likelihood: ", stat$log_lik, "\n\n"))
    }
  }

  # Computation of c_ig the hard partition of the curves and klas
  statSolution$MAP()

  if (n_tries > 1 && verbose) {
    cat(paste0("Best value of the log-likelihood: ", statSolution$loglik, "\n"))
  }

  statSolution$computeStats(paramSolution)

  return(ModelMixRHLP(param = paramSolution, stat = statSolution))
}