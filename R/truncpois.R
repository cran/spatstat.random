#' Truncated Poisson random variables
#'
#'  $Revision: 1.5 $ $Date: 2023/02/13 10:57:29 $
#' 
#'   Copyright (C) Adrian Baddeley and Ya-Mei Chang 2022 
#'   GNU Public Licence >= 2

rpoisnonzero <- function(n, lambda, method=c("harding", "transform"), implem=c("R", "C")) {
  ## Poisson random variable, conditioned to be nonzero
  method <- match.arg(method)
  implem <- match.arg(implem)
  switch(implem,
         R = {
           switch(method,
                  harding = {
                    ## From a post by Ted Harding (2005)
                    lam1 <- lambda + log(runif(n, min=exp(-lambda), max=1))
                    lam1 <- pmax(0, lam1) ## avoid numerical glitches (lam1 is theoretically > 0)
                    y <- rpois(n, lam1) + 1L
                  },
                  transform = {
                    ## From a post by Peter Dalgaard (2005) in response to Harding
                    ## Surprisingly, this is 3 times slower!
                    y <- as.integer(qpois(runif(n, min=exp(-lambda), max=1), lambda))
                  })
         },
         C = {
           storage.mode(n) <- "integer"
           storage.mode(lambda) <- "double"
           switch(method,
                  harding = {
                    y <- .Call(SR_RrnzpoisHarding,
                               n, lambda,
                               PACKAGE="spatstat.random")
                  },
                  transform = {
                    y <- .Call(SR_RrnzpoisDalgaard,
                               n, lambda,
                               PACKAGE="spatstat.random")
                  })
         })
  return(y)
}

rpoistrunc <- function(n, lambda, minimum=1, method=c("harding", "transform"), implem=c("R", "C")) {
  ## Poisson random variable, conditioned to be at least 'minimum'
  stopifnot(all(is.finite(minimum)))
  minimum <- pmax(0L, as.integer(minimum))
  method <- match.arg(method)
  implem <- match.arg(implem)
  switch(implem,
         R = {
           switch(method,
                  transform = {
                    y <- qpois(runif(n, min=ppois(minimum-1L, lambda), max=1), lambda)
                  },
                  harding = {
                    if(length(minimum) == 1) {
                      for(k in seq_len(minimum)) 
                        lambda <- pmax(0, lambda + log(1 - runif(n) * (1 - exp(-lambda))))
                    } else if(length(minimum) == n) {
                      if(length(lambda) == 1) lambda <- rep(lambda, n)
                      remaining <- minimum
                      while(any(todo <- (remaining > 0))) {
                        lambda[todo] <- pmax(0, lambda[todo] + log(1 - runif(sum(todo)) * (1 - exp(-lambda[todo]))))
                        remaining[todo] <- remaining[todo] - 1L
                      }
                    } else stop("Argument 'minimum' should be a vector of length 1 or n", call.=FALSE)
                    y <- rpois(n, lambda) + minimum
                  })
         },
         C = {
           storage.mode(n) <- "integer"
           storage.mode(lambda) <- "double"
           storage.mode(minimum) <- "integer"
           switch(method,
                  harding = {
                    y <- .Call(SR_RrtruncpoisHarding,
                               n, lambda, minimum, 
                               PACKAGE="spatstat.random")
                  },
                  transform = {
                    y <- .Call(SR_RrtruncpoisDalgaard,
                               n, lambda, minimum, 
                               PACKAGE="spatstat.random")
                  })
         })
  return(y)
}

recipEnzpois <- function(mu, exact=TRUE) {
  ## first reciprocal moment of nzpois
  if(exact && isNamespaceLoaded("gsl")) {
    gamma <- -digamma(1)
    ans <- (gsl::expint_Ei(mu) - log(mu) - gamma) * exp(-mu) /(1 - exp(-mu))
    return(ans)
  } else {
    n <- length(mu)
    ans <- numeric(n)
    xx <- 1:max(ceiling(mu + 6 * sqrt(mu)), 100)
    for(i in 1:n) 
      ans[i] <- sum(dpois(xx, mu[i])/xx)/(1 - exp(-mu[i]))
  }
  return(ans)
}
