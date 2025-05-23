##
##    random.R
##
##    Functions for generating random point patterns
##
##    $Revision: 4.124 $   $Date: 2025/03/15 03:40:12 $
##
##    runifpoint()      n i.i.d. uniform random points ("binomial process")
##    runifdisc()       special case of disc (faster)
##
##    runifpoispp()     uniform Poisson point process
##
##    rpoispp()         general Poisson point process (thinning method)
##
##    rpoint()          n independent random points (rejection/pixel list)
##
##    rMaternI()        Mat'ern model I 
##    rMaternII()       Mat'ern model II
##    rMaternInhibition Generalisation

##    rSSI()            Simple Sequential Inhibition process
##
##    rPoissonCluster() generic Poisson cluster process
##    rGaussPoisson()   Gauss-Poisson process
##
##    rthin()           independent random thinning
##    rcell()           Baddeley-Silverman cell process
##
##    Examples:
##          u01 <- owin(0:1,0:1)
##          plot(runifpoispp(100, u01))
##          X <- rpoispp(function(x,y) {100 * (1-x/2)}, 100, u01)
##          X <- rpoispp(function(x,y) {ifelse(x < 0.5, 100, 20)}, 100)
##          plot(X)
##          plot(rMaternI(100, 0.02))
##          plot(rMaternII(100, 0.05))
##

runifdisc <- function(n, radius=1, centre=c(0,0), ..., nsim=1, drop=TRUE)
{
  ## i.i.d. uniform points in the disc of radius r and centre (x,y)
  check.1.real(radius)
  stopifnot(radius > 0)
  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
  }
  disque <- disc(centre=centre, radius=radius, ...)
  twopi <- 2 * pi
  rad2 <- radius^2
  result <- vector(mode="list", length=nsim)
  for(isim in seq_len(nsim)) {
    theta <- runif(n, min=0, max=twopi)
    s <- sqrt(runif(n, min=0, max=rad2))
    result[[isim]] <- ppp(centre[1] + s * cos(theta),
                          centre[2] + s * sin(theta),
                          window=disque, check=FALSE)
  }
  result <- simulationresult(result, nsim, drop)
  return(result)
}


runifpoint <- function(n, win=owin(c(0,1),c(0,1)),
                       giveup=1000, warn=TRUE, ...,
                       nsim=1, drop=TRUE, ex=NULL)
{
  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
  }
  
  if(missing(n) && missing(win) && !is.null(ex)) {
    stopifnot(is.ppp(ex))
    n <- npoints(ex)
    win <- Window(ex)
  } else if(is.tess(win)) {
    W <- Window(win)
    pieces <- tiles(win)
    ntiles <- length(pieces)
    check.nvector(n, ntiles, things="tiles", oneok=TRUE, vname="n")
    if(length(n) == 1) n <- rep(n, ntiles)
    Y <- mapply(runifpoint, n=n, win=pieces,
                MoreArgs=list(nsim=nsim, drop=FALSE, giveup=giveup, warn=warn),
                SIMPLIFY=FALSE, USE.NAMES=FALSE)
    result <- vector(mode="list", length=nsim)
    for(isim in seq_len(nsim)) {
      result[[isim]] <- superimpose(solapply(Y, "[[", i=isim), W=W, check=FALSE)
    }
    result <- simulationresult(result, nsim, drop)
    return(result)
  } else {
    ## usual case
    win <- as.owin(win)
    check.1.integer(n)
    stopifnot(n >= 0)
  }

  if(n == 0) {
    emp <- ppp(window=win)
    result <- rep(list(emp), nsim)
    result <- simulationresult(result, nsim, drop)
    return(result)
  }

  if(warn) {
    nhuge <- spatstat.options("huge.npoints")
    if(n > nhuge) {
      whinge <- paste("Attempting to generate", n, "random points")
      message(whinge)
      warning(whinge, call.=FALSE)
    }
  }

  switch(win$type,
         rectangle = {
           return(runifrect(n, win, nsim=nsim, drop=drop))
         },
         mask = {
           dx <- win$xstep
           dy <- win$ystep
           ## extract pixel coordinates and probabilities
           rxy <- rasterxy.mask(win, drop=TRUE)
           xpix <- rxy$x
           ypix <- rxy$y
           ## make a list of nsim point patterns
           result <- vector(mode="list", length=nsim)
           for(isim in seq_len(nsim)) {
             ## select pixels with equal probability
             id <- sample(seq_along(xpix), n, replace=TRUE)
             ## extract pixel centres and randomise within pixels
             x <- xpix[id] + runif(n, min= -dx/2, max=dx/2)
             y <- ypix[id] + runif(n, min= -dy/2, max=dy/2)
             result[[isim]] <- ppp(x, y, window=win, check=FALSE)
           }
         },
         polygonal={
           ## make a list of nsim point patterns
           result <- vector(mode="list", length=nsim)
           for(isim in seq_len(nsim)) {
             ## rejection method
             ## initialise empty pattern
             x <- numeric(0)
             y <- numeric(0)
             X <- ppp(x, y, window=win)
             ##
             ## rectangle in which trial points will be generated
             box <- boundingbox(win)
             ## 
             ntries <- 0
             repeat {
               ntries <- ntries + 1
               ## generate trial points in batches of n
               qq <- runifrect(n, box) 
               ## retain those which are inside 'win'
               qq <- qq[win]
               ## add them to result
               X <- superimpose(X, qq, W=win, check=FALSE)
               ## if we have enough points, exit
               if(X$n > n) {
                 result[[isim]] <- X[1:n]
                 break
               } else if(X$n == n) {
                 result[[isim]] <- X
                 break
               } else if(ntries >= giveup) {
                 ## otherwise get bored eventually
                 stop(paste("Gave up after", giveup * n, "trials,",
                            X$n, "points accepted"))
               }
             }
           }
         },
         stop("Unrecognised window type")
         )
  
  ## list of point patterns produced.
  result <- simulationresult(result, nsim, drop)
  return(result)
}


runifpoispp <- function(lambda, win = owin(c(0,1),c(0,1)), ...,
                        nsim=1, drop=TRUE) {
  win <- as.owin(win)
  if(!is.numeric(lambda) || length(lambda) > 1 ||
     !is.finite(lambda) || lambda < 0)
    stop("Intensity lambda must be a single finite number >= 0")
  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
  }

  if(lambda == 0) {
    ## return empty pattern
    emp <- ppp(window=win)
    result <- rep(list(emp), nsim)
    result <- simulationresult(result, nsim, drop)
    return(result)
  }

  ## will generate Poisson process in enclosing rectangle and trim it
  box <- boundingbox(win)
  meanN <- lambda * area(box)
  
  result <- vector(mode="list", length=nsim)
  for(isim in seq_len(nsim)) {
    n <- rpois(1, meanN)
    if(!is.finite(n))
      stop(paste("Unable to generate Poisson process with a mean of",
                 meanN, "points"))
    X <- runifpoint(n, box)
    ## trim to window
    if(win$type != "rectangle")
      X <- X[win]
    result[[isim]] <- X
  }
  result <- simulationresult(result, nsim, drop)
  return(result)
}

rpoint <- function(n, f, fmax=NULL,
                   win=unit.square(), ..., giveup=1000, warn=TRUE, verbose=FALSE,
                   nsim=1, drop=TRUE, forcewin=FALSE) {
  
  if(missing(f) || (is.numeric(f) && length(f) == 1))
    ## uniform distribution
    return(runifpoint(n, win, giveup=giveup, warn=warn, nsim=nsim, drop=drop))
  
  ## non-uniform distribution....
  if(!is.function(f) && !is.im(f))
    stop(paste(sQuote("f"),
               "must be either a function or an",
               sQuote("im"), "object"))

  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
  }
  
  if(is.im(f)) {
    ## ------------ PIXEL IMAGE ---------------------
    if(forcewin) {
      ## force simulation points to lie inside 'win'
      f <- f[win, drop=FALSE]
      win.out <- win
    } else {
      ## default - ignore 'win'
      win.out <- as.owin(f)
    }
    if(n == 0) {
      ## return empty pattern(s)
      emp <- ppp(window=win.out)
      result <- rep(list(emp), nsim)
      result <- simulationresult(result, nsim, drop)
      return(result)
    }
    ## need to check simulated point coordinates?
    checkinside <- forcewin
    if(checkinside && is.rectangle(win) && is.subset.owin(Frame(f), win))
      checkinside <- FALSE
    ## prepare
    w <- as.mask(if(forcewin) f else win.out)
    M <- w$m
    dx <- w$xstep
    dy <- w$ystep
    halfdx <- dx/2.0
    halfdy <- dy/2.0
    ## extract pixel coordinates and probabilities
    rxy <- rasterxy.mask(w, drop=TRUE)
    xpix <- rxy$x
    ypix <- rxy$y
    npix <- length(xpix)
    ppix <- as.vector(f$v[M]) ## not normalised - OK
    ## generate
    result <- vector(mode="list", length=nsim)
    for(isim in seq_len(nsim)) {
      ## select pixels
      id <- sample(npix, n, replace=TRUE, prob=ppix)
      ## extract pixel centres and randomise location within pixels
      x <- xpix[id] + runif(n, min= -halfdx, max=halfdx)
      y <- ypix[id] + runif(n, min= -halfdy, max=halfdy)
      if(checkinside) {
        edgy <- which(!inside.owin(x,y,win.out))
        ## reject points just outside boundary
        ntries <- 0
        while((nedgy <- length(edgy)) > 0) {
          ntries <- ntries + 1
          ide <- sample(npix, nedgy, replace=TRUE, prob=ppix)
          x[edgy] <- xe <- xpix[ide] + runif(nedgy, min= -halfdx, max=halfdx)
          y[edgy] <- ye <- ypix[ide] + runif(nedgy, min= -halfdy, max=halfdy)
          edgy <- edgy[!inside.owin(xe, ye, win.out)]
          if(ntries > giveup) break;
        }
      }
      result[[isim]] <- ppp(x, y, window=win.out, check=FALSE)
    }
    result <- simulationresult(result, nsim, drop)
    return(result)
  }

  ## ------------ FUNCTION  ---------------------  
  ## Establish parameters for rejection method

  verifyclass(win, "owin")

  if(n == 0) {
    ## return empty pattern(s)
    emp <- ppp(window=win)
    result <- rep(list(emp), nsim)
    result <- simulationresult(result, nsim, drop)
    return(result)
  }
  
  if(is.null(fmax)) {
    ## compute approx maximum value of f
    imag <- as.im(f, win, ...)
    summ <- summary(imag)
    fmax <- summ$max + 0.05 * diff(summ$range)
  }
  irregular <- (win$type != "rectangle")
  box <- boundingbox(win)

  result <- vector(mode="list", length=nsim)
  for(isim in seq_len(nsim)) {

    ## initialise empty pattern
    X <- ppp(numeric(0), numeric(0), window=win)
  
    pbar <- 1
    nremaining <- n
    totngen <- 0
    
    ## generate uniform random points in batches
    ## and apply the rejection method.
    ## Collect any points that are retained in X

    ntries <- 0
    repeat{
      ntries <- ntries + 1
      ## proposal points
      ngen <- nremaining/pbar + 10
      totngen <- totngen + ngen
      prop <- runifrect(ngen, box)
      if(irregular)
        prop <- prop[win]
      if(prop$n > 0) {
        fvalues <- f(prop$x, prop$y, ...)
        paccept <- fvalues/fmax
        u <- runif(prop$n)
        ## accepted points
        Y <- prop[u < paccept]
        if(Y$n > 0) {
          ## add to X
          X <- superimpose(X, Y, W=win, check=FALSE)
          nX <- X$n
          pbar <- nX/totngen
          nremaining <- n - nX
          if(nremaining <= 0) {
            ## we have enough!
            if(verbose)
              splat("acceptance rate = ", round(100 * pbar, 2), "%")
            result[[isim]] <- if(nX == n) X else X[1:n]
            break
          }
        }
      }
      if(ntries > giveup)
        stop(paste("Gave up after",giveup * n,"trials with",
                   X$n, "points accepted"))
    }
  }
  result <- simulationresult(result, nsim, drop)
  return(result)
}

rpoispp <- function(lambda, lmax=NULL, win = owin(), ...,
                    nsim=1, drop=TRUE, ex=NULL,
                    forcewin=FALSE, warnwin=TRUE) {
  ## arguments:
  ##     lambda  intensity: constant, function(x,y,...) or image
  ##     lmax     maximum possible value of lambda(x,y,...)
  ##     win     default observation window (of class 'owin')
  ##   ...       arguments passed to lambda(x, y, ...)
  ##     nsim    number of replicate simulations

  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
  }

  if(!missing(lambda) && inherits(lambda, "tessfun")) {
    ## intensity is constant on each tile of a tessellation
    ## use special algorithm
    if(missing(win)) win <- NULL
    result <- rpoisTessfun(lambda, win=win, nsim=nsim, drop=drop, ...)
    return(result)
  }
  
  if(missing(lambda) && is.null(lmax) && missing(win) && !is.null(ex)) {
    ## use example pattern 'ex'
    lambda <- intensity(unmark(ex))
    win <- Window(ex)
  } else {
    if(!(is.numeric(lambda) || is.function(lambda) || is.im(lambda)))
      stop(paste(sQuote("lambda"),
                 "must be a constant, a function or an image"))
    if(is.numeric(lambda) && !(length(lambda) == 1 && lambda >= 0))
      stop(paste(sQuote("lambda"),
                 "must be a single, nonnegative number"))
    if(!is.null(lmax)) {
      if(!is.numeric(lmax))
        stop("lmax should be a number")
      if(length(lmax) > 1)
        stop("lmax should be a single number")
    }
    win.given <- !missing(win) && !is.null(win)
    if(win.given) win <- as.owin(win)
    if(is.im(lambda)) {
      if(win.given && forcewin) {
        ## user-specified 'win' overrides default
        lambda <- lambda[win, drop=FALSE]
      } else {
        ## default 
        win <- rescue.rectangle(as.owin(lambda))
        if(win.given && warnwin)
          warning(paste("Argument", sQuote("win"), "ignored in rpoispp"),
                  call.=FALSE)
      }
    }
  }
  
  if(is.numeric(lambda)) {
    ## uniform Poisson
    return(runifpoispp(lambda, win, nsim=nsim, drop=drop))
  }

  ## inhomogeneous Poisson
  ## perform thinning of uniform Poisson
  ## determine upper bound
  if(is.null(lmax)) {
    imag <- as.im(lambda, win, ...)
    summ <- summary(imag)
    lmax <- summ$max + 0.05 * diff(summ$range)
  } 

  if(is.function(lambda)) {
    ## function lambda
    #'      runifpoispp checks 'lmax'
    result <- runifpoispp(lmax, win, nsim=nsim, drop=FALSE)
    #'      result is a 'ppplist' with appropriate names
    for(isim in seq_len(nsim)) {
      X <- result[[isim]]
      if(X$n > 0) {
        prob <- lambda(X$x, X$y, ...)/lmax
        u <- runif(X$n)
        retain <- is.finite(prob) & (u <= prob)
        result[[isim]] <- X[retain]
      }
    }
    return(simulationresult(result, nsim, drop))
  }

  if(is.im(lambda)) {
    ## image lambda
    if(spatstat.options("fastpois")) {
      ## new code: sample pixels directly
      mu <- integral(lambda)
      dx <- lambda$xstep/2
      dy <- lambda$ystep/2
      df <- as.data.frame(lambda)
      npix <- nrow(df)
      lpix <- df$value
      result <- vector(mode="list", length=nsim)
      nn <- rpois(nsim, mu)
      if(!all(is.finite(nn)))
        stop(paste("Unable to generate Poisson process with a mean of",
                   mu, "points"))
      for(isim in seq_len(nsim)) {
        ni <- nn[isim]
        ii <- sample.int(npix, size=ni, replace=TRUE, prob=lpix)
        xx <- df$x[ii] + runif(ni, -dx, dx)
        yy <- df$y[ii] + runif(ni, -dy, dy)
        result[[isim]] <- ppp(xx, yy, window=win, check=FALSE)
      }
      result <- simulationresult(result, nsim, drop)
      return(result)
    } else {
      ## old code: thinning
      result <- runifpoispp(lmax, win, nsim=nsim, drop=FALSE)
      for(isim in seq_len(nsim)) {
        X <- result[[isim]]
        if(X$n > 0) {
          prob <- lambda[X, drop=FALSE]/lmax
          u <- runif(X$n)
          retain <- is.finite(prob) & (u <= prob)
          result[[isim]] <- X[retain]
        }
      }
      return(simulationresult(result, nsim, drop))
    }
  }
  stop(paste(sQuote("lambda"), "must be a constant, a function or an image"))
}
    
rpoisTessfun <- function(lambda, win=NULL, ..., nsim=1, drop=TRUE,
                         tilewise=NULL, verbose=TRUE) {
  ## special case of rpoispp: constant intensity on each tile of tessellation
  stopifnot(inherits(lambda, "tessfun"))
  tes <- as.tess(lambda)
  lam <- as.numeric(tessfunvalues(lambda))
  lmax <- max(lam)
  Wfull <- Window(as.tess(lambda))
  if(is.null(win)) win <- Wfull else stopifnot(is.owin(win))
  if(length(tilewise) == 0) {
    ## decide which algorithm to use
    switch(tes$type,
           rect = ,
           tiled = {
             En <- integral(lambda)
             Em <- lmax * area(Wfull)
             tilewise <- (Em > .Machine$integer.max) || (En < Em/1e3)
             if(verbose)
               message("Using ", if(tilewise) "tilewise" else "rejection",
                       " algorithm")
           },
           image = {
             ## No benefit in splitting by tiles
             tilewise <- FALSE
           })
  }
  if(isFALSE(tilewise)) {
    ## use rejection algorithm 
    class(lambda) <- setdiff(class(lambda), "tessfun")
    result <- rpoispp(lambda, lmax=lmax, win=win, ..., nsim=nsim, drop=drop)
    return(result)
  }
  B <- Frame(win)
  til <- tiles(tes)
  nt <- length(til)
  for(j in seq_len(nt)) {
    ## generate 'nsim' patterns in tile 'j'
    Uj <- runifpoispp(lam[j], til[[j]], nsim=nsim, drop=FALSE)
    ## extract coordinates as list(list(x,y), list(x,y), ...)
    if(j == 1) {
      xylist <- lapply(Uj, concatxy)
    } else {
      xylist <- mapply(concatxy, xylist, Uj, SIMPLIFY=FALSE)
    }
  }
  ## create point pattern objects
  result <- lapply(xylist, as.ppp, W=B, check=FALSE)
  ## clip to 'win'
  result <- lapply(result, "[", i=win)
  return(simulationresult(result, nsim, drop))
}

rMaternI <- function(kappa, r, win = owin(c(0,1),c(0,1)), stationary=TRUE,
                     ..., nsim=1, drop=TRUE)
{
  rMaternInhibition(type=1,
                    kappa=kappa, r=r, win=win, stationary=stationary,
                    ..., nsim=nsim, drop=drop)
}

rMaternII <- function(kappa, r, win = owin(c(0,1),c(0,1)), stationary=TRUE,
                     ..., nsim=1, drop=TRUE)
{
  rMaternInhibition(type=2,
                    kappa=kappa, r=r, win=win, stationary=stationary,
                    ..., nsim=nsim, drop=drop)
}

rMaternInhibition <- function(type, 
                              kappa, r, win = owin(c(0,1),c(0,1)),
                              stationary=TRUE,
                              ..., nsim=1, drop=TRUE) {
  stopifnot(is.numeric(r) && length(r) == 1)
  stopifnot(type %in% c(1,2))
  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
  }
  ## Resolve window class
  if(!inherits(win, c("owin", "box3", "boxx"))) {
    givenwin <- win
    win <- try(as.owin(givenwin), silent = TRUE)
    if(inherits(win, "try-error"))
      win <- try(as.boxx(givenwin), silent = TRUE)
    if(inherits(win, "try-error"))
      stop("Could not coerce argument win to a window (owin, box3 or boxx).")
  }
  dimen <- spatdim(win)
  if(dimen == 2) {
    bigbox <- if(stationary) grow.rectangle(win, r) else win
    result <- rpoispp(kappa, win = bigbox, nsim = nsim, drop=FALSE)
  } else if(dimen == 3) {
    bigbox <- if(stationary) grow.box3(win, r) else win
    result <- rpoispp3(kappa, domain = bigbox, nsim = nsim, drop=FALSE)
  } else {
    bigbox <- if(stationary) grow.boxx(win, r) else win
    result <- rpoisppx(kappa, domain = bigbox, nsim = nsim, drop=FALSE)
  }
  for(isim in seq_len(nsim)) {
    Y <- result[[isim]]
    nY <- npoints(Y)
    if(type == 1) {
      ## Matern Model I
      if(nY > 1) {
        d <- nndist(Y)
        Y <- Y[d > r]
      }
    } else {
      ## Matern Model II
      if(nY > 1) {
        ## matrix of squared pairwise distances
        d2 <- pairdist(Y, squared=TRUE)
        close <- (d2 <= r^2)
        ## random order 1:n
        age <- sample(seq_len(nY), nY, replace=FALSE)
        earlier <- outer(age, age, ">")
        conflict <- close & earlier
        ## delete <- apply(conflict, 1, any)
        delete <- matrowany(conflict)
        Y <- Y[!delete]
      }
    }
    if(stationary)
      Y <- Y[win]
    result[[isim]] <- Y
  }
  if(nsim == 1 && drop) return(result[[1L]])
  if(is.owin(win))
    result <- as.ppplist(result)
  return(result)
}

rSSI <- function(r, n=Inf, win = square(1), 
                 giveup = 1000, x.init=NULL, ...,
                 f=NULL, fmax=NULL,
                 nsim=1, drop=TRUE, verbose=TRUE)
{
  win.given <- !missing(win) && !is.null(win)
  stopifnot(is.numeric(r) && length(r) == 1 && r >= 0)
  stopifnot(is.numeric(n) && length(n) == 1 && n >= 0)
  must.reach.n <- is.finite(n)
  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 1)
  }
  ## 'verbose' applies only when nsim > 1
  verbose <- verbose && (nsim > 1)
  ##
  if(!is.null(f)) {
    stopifnot(is.numeric(f) || is.im(f) || is.function(f))
    if(is.null(fmax) && !is.numeric(f))
      fmax <- if(is.im(f)) max(f) else max(as.im(f, win))
  }
  ##
  result <- vector(mode="list", length=nsim)
  if(!win.given) win <- square(1)
  ## validate initial state
  if(is.null(x.init)) {
    ## start with empty pattern in specified window
    win <- as.owin(win)
    x.init <- ppp(numeric(0),numeric(0), window=win)
  } else {
    ## start with specified pattern
    stopifnot(is.ppp(x.init))
    if(!win.given) {
      win <- as.owin(x.init)
    } else {
      ## check compatibility of windows
      if(!identical(win, as.owin(x.init)))
        warning(paste("Argument", sQuote("win"),
                      "is not the same as the window of", sQuote("x.init")))
      x.init.new <- x.init[win]
      if(npoints(x.init.new) == 0)
        stop(paste("No points of x.init lie inside the specified window",
                   sQuote("win")))
      nlost <- npoints(x.init) - npoints(x.init.new)
      if(nlost > 0) 
        warning(paste(nlost, "out of",
                      npoints(x.init), "points of the pattern x.init",
                      "lay outside the specified window",
                      sQuote("win")))
      x.init <- x.init.new
    }
    if(n < npoints(x.init))
      stop(paste("x.init contains", npoints(x.init), "points",
                 "but a pattern containing only n =", n, "points", 
                 "is required"))
    if(n == npoints(x.init)) {
      warning(paste("Initial state x.init already contains", n, "points;",
                    "no further points were added"))
      result <- rep(list(x.init), nsim)
      result <- simulationresult(result, nsim, drop)
      return(result)
    }
  }
  #' validate radius and 'n' 
  r2 <- r^2
  winArea <- area(win)
  discarea <- pi * r2/4
  nmelt <- floor(winArea/discarea)
  packdensity <- pi * sqrt(3)/6
  npack <- floor(packdensity * winArea/discarea)
  if(is.finite(n)) {
    if(n > nmelt) {
      warning(paste("Window is too small to fit", n, "points",
                    "at minimum separation", r,
                    paren(paste("absolute maximum number is", nmelt))))
    } else if(n > npack) {
      warning(paste("Window is probably too small to fit", n, "points",
                    "at minimum separation", r,
                    paren(paste("packing limit is", nmelt))))
    }
  }

  #' start simulation 		    
  pstate <- list()
  if(verbose) splat("Generating", nsim, "realisations...")
  for(isim in seq_len(nsim)) {
    if(verbose) pstate <- progressreport(isim, nsim, state=pstate)
    ## Simple Sequential Inhibition process
    ## fixed number of points
    xx <- coords(x.init)$x
    yy <- coords(x.init)$y
    nn <- npoints(x.init)
    ## Naive implementation, proposals are uniform
    xprop <- yprop <- numeric(0)
    nblock <- if(is.finite(n)) n else min(1024, nmelt)
    ntries <- 0
    while(ntries < giveup) {
      ntries <- ntries + 1
      if(length(xprop) == 0) {
        ## generate some more proposal points
        prop <- if(is.null(f)) runifpoint(nblock, win) else
                               rpoint(nblock, f, fmax, win)
        xprop <- coords(prop)$x
        yprop <- coords(prop)$y
      }
      ## extract next proposal
      xnew <- xprop[1L]
      ynew <- yprop[1L]
      xprop <- xprop[-1L]
      yprop <- yprop[-1L]
      ## check hard core constraint
      dx <- xnew - xx
      dy <- ynew - yy
      if(!any(dx^2 + dy^2 <= r2)) {
        xx <- c(xx, xnew)
        yy <- c(yy, ynew)
        nn <- nn + 1L
        ntries <- 0
      }
      if(nn >= n)
        break
    }
    if(must.reach.n && nn < n)
      warning(paste("Gave up after", giveup,
                    "attempts with only", nn, "points placed out of", n))
    X <- ppp(xx, yy, window=win, check=FALSE)
    result[[isim]] <- X
  }
  result <- simulationresult(result, nsim, drop)
  return(result)
}

rPoissonCluster <-
  function(kappa, expand, rcluster, win = owin(c(0,1),c(0,1)), ...,
           nsim=1, drop=TRUE, saveparents=TRUE, kappamax=NULL)
{
  ## Generic Poisson cluster process
  ## Implementation for bounded cluster radius
  ##
  ## 'rcluster' is a function(x,y) that takes the coordinates
  ## (x,y) of the parent point and generates a list(x,y) of offspring
  ##
  ## "..." are arguments to be passed to 'rcluster()'
  ##

  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
    if(nsim == 0) return(simulationresult(list()))
  }

  ## Catch old argument name rmax for expand, and allow rmax to be
  ## passed to rcluster (and then be ignored)
  if(missing(expand) && !is.null(rmax <- list(...)$rmax)) {
    warning("outdated usage in rPoissonCluster: 'rmax' should be 'expand'")
    expand <- rmax
  }

  rPoissonClusterEngine(kappa=kappa, expand=expand, rcluster=rcluster,
                        win=win, nsim=nsim, drop=drop, saveparents=saveparents,
                        kappamax=kappamax, ...)
}

rPoissonClusterEngine <- function(kappa, expand=rmax, rcluster, win, ..., 
                                  nsim=1, drop=TRUE, saveparents=TRUE,
                                  kappamax=lmax, lmax=NULL, rmax=NULL) {
  ## Generate parents in dilated window
  win <- as.owin(win)
  frame <- boundingbox(win)
  dilated <- owinInternalRect(frame$xrange + c(-expand, expand),
                  frame$yrange + c(-expand, expand))

  if(is.im(kappa) && !is.subset.owin(dilated, as.owin(kappa)))
    stop(paste("The window in which the image",
               sQuote("kappa"),
               "is defined\n",
               "is not large enough to contain the dilation of the window",
               sQuote("win")))

  parentlist <- rpoispp(kappa, lmax=kappamax, win=dilated,
                        nsim=nsim, drop=FALSE)

  resultlist <- vector(mode="list", length=nsim)
  for(isim in seq_len(nsim)) {
    parents <- parentlist[[isim]]
    result <- NULL
    ## generate clusters
    np <- parents$n
    if(np > 0) {
      xparent <- parents$x
      yparent <- parents$y
      for(i in seq_len(np)) {
        ## generate random offspring of i-th parent point
        cluster <- rcluster(xparent[i], yparent[i], ...)
        if(!inherits(cluster, "ppp"))
          cluster <- ppp(cluster$x, cluster$y, window=frame, check=FALSE)
        ## skip if cluster is empty
        if(cluster$n > 0) {
          ## trim to window
          cluster <- cluster[win]
          if(is.null(result)) {
            ## initialise offspring pattern and offspring-to-parent map
            result <- cluster
            parentid <- rep.int(1, cluster$n)
          } else {
            ## add to pattern
            result <- superimpose(result, cluster, W=win, check=FALSE)
            ## update offspring-to-parent map
            parentid <- c(parentid, rep.int(i, cluster$n))
          }
        }
      }
    } else {
      ## no parents - empty pattern
      result <- ppp(numeric(0), numeric(0), window=win)
      parentid <- integer(0)
    }

    if(saveparents) {
      attr(result, "parents") <- parents
      attr(result, "parentid") <- parentid
      attr(result, "expand") <- expand
    }
    
    resultlist[[isim]] <- result
  }

  result <- simulationresult(resultlist, nsim, drop)
  return(result)
}  

rGaussPoisson <- local({
  
  rGaussPoisson <- function(kappa, r, p2, win=owin(c(0,1), c(0,1)),
                            ..., nsim=1, drop=TRUE) {
    ## Gauss-Poisson process
    result <- rPoissonCluster(kappa, 1.05 * r, oneortwo,
                              win, radius=r/2, p2=p2, nsim=nsim, drop=drop)
    return(result)
  }

  oneortwo <- function(x0, y0, radius, p2) {
    if(runif(1) > p2) 
      ## one point
      return(list(x=x0, y=y0))
    ## two points
    theta <- runif(1, min=0, max=2*pi)
    return(list(x=x0+c(-1,1)*radius*cos(theta),
                y=y0+c(-1,1)*radius*sin(theta)))
  }

  rGaussPoisson
})

  
rstrat <- function(win=square(1), nx, ny=nx, k=1, nsim=1, drop=TRUE) {
  win <- as.owin(win)
  stopifnot(nx >= 1 && ny >= 1)
  stopifnot(k >= 1)
  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
  }
  result <- vector(mode="list", length=nsim)
  for(isim in seq_len(nsim)) {
    xy <- stratrand(win, nx, ny, k)
    Xbox <- ppp(xy$x, xy$y, win$xrange, win$yrange, check=FALSE)
    result[[isim]] <- Xbox[win]
  }
  result <- simulationresult(result, nsim, drop)
  return(result)
}

  
rcellnumber <- local({

  rcellnumber <- function(n, N=10, mu=1) {
    if(missing(mu) || mu == 1) {
      z <- rCellUnit(n=n, N=N)
    } else {
      z <- replicate(n, rCellCumul(x=mu, N=N))
    }
    return(z)
  }
  
  rCellUnit <- function(n, N=10) {
    if(!missing(N)) {
      if(round(N) != N) stop("N must be an integer")
      stopifnot(is.finite(N))
      stopifnot(N > 1)
    }
    u <- runif(n, min=0, max=1)
    p0 <- 1/N
    pN <- 1/(N * (N-1))
    k <- ifelse(u < p0, 0, ifelse(u < (1 - pN), 1, N))
    return(k)
  }
  
  rCellCumul <- function(x, N=10) {
    check.1.real(x)
    n <- ceiling(x)
    if(n <= 0) return(0)
    y <- rCellUnit(n=n, N=N)
    if(n == x) return(sum(y))
    p <- x - (n-1)
    z <- sum(y[-1]) + rbinom(1, size=y[1], prob=p)
    return(z)
  }

  rcellnumber
})

rcell <- function(win=square(1), nx=NULL, ny=nx, ...,
                  dx=NULL, dy=dx, N=10, nsim=1, drop=TRUE) {
  if(!missing(nsim)) {
    check.1.integer(nsim)
    stopifnot(nsim >= 0)
    if(nsim == 0) return(simulationresult(list()))
  }
  win <- as.owin(win)
  xr <- win$xrange
  yr <- win$yrange
  ## determine grid coordinates 
  if(missing(ny)) ny <- NULL
  if(missing(dy)) dy <- NULL
  g <- xy.grid(xr, yr, nx, ny, dx, dy)
  nx <- g$nx
  ny <- g$ny
  x0 <- g$x0
  y0 <- g$y0
  dx <- g$dx
  dy <- g$dy
  ## generate pattern(s)
  result <- vector(mode="list", length=nsim)
  for(isim in seq_len(nsim)) {
    x <- numeric(0)
    y <- numeric(0)
    for(ix in seq_len(nx))
      for(iy in seq_len(ny)) {
        nij <- rcellnumber(1, N)
        x <- c(x, x0[ix] + runif(nij, min=0, max=dx))
        y <- c(y, y0[iy] + runif(nij, min=0, max=dy))
      }
    Xbox <- ppp(x, y, xr, yr, check=FALSE)
    result[[isim]] <- Xbox[win]
  }
  result <- simulationresult(result, nsim, drop)
  return(result)
}


thinjump <- function(n, p) {
  # equivalent to which(runif(n) < p) for constant p
  stopifnot(length(p) == 1)
  if(p <= 0) return(integer(0))
  if(p >= 1) return(seq_len(n))
  if(p > 0.5) {
    #' for retention prob > 0.5 we find the ones to discard instead
    discard <- thinjump(n, 1-p)
    retain <- if(length(discard)) -discard else seq_len(n)
    return(retain)
  }
  guessmaxlength <- ceiling(n * p + 2 * sqrt(n * p * (1-p)))
  i <- .Call(SR_thinjumpequal,
             n, p, guessmaxlength,
             PACKAGE="spatstat.random")
  return(i)
}

rthin <- function(X, P, ..., nsim=1, drop=TRUE) {
  if(!(inherits(X, c("ppp", "lpp", "pp3", "ppx", "psp")) ||
       recognise.spatstat.type(X) == "listxy"))
    stop(paste("X should be a point pattern (class ppp, lpp, pp3 or ppx)",
               "or a line segment pattern (class psp)"),
         call.=FALSE)
  rthinEngine(X, P, ..., nsim=nsim, drop=drop)
}

rthinEngine <- function(X, P, ..., nsim=1, drop=TRUE,
                        Pmax=1, na.zero=FALSE,
                        what=c("objects", "fate"),
                        fatal=TRUE, warn=TRUE) {
  check.1.integer(nsim)
  stopifnot(nsim >= 0)
  ## if what = 'objects', return the thinned pattern
  ## if what = 'fate', return the logical vector (retained/deleted)
  what <- match.arg(what)
  ## recognise list(x,y) input
  if(israwxy <- (recognise.spatstat.type(X) == "listxy")) {
    xx <- X$x
    yy <- X$y
    nX <- length(xx)
  } else {
    nX <- nobjects(X)
  }
  ## catch trivial cases
  if(nX == 0 || nsim == 0) {
    switch(what,
           objects = {
             result <- rep(list(X), nsim)
           },
           fate = {
             result <- rep(list(logical(nX)), nsim)
           })
    result <- simulationresult(result, nsim, drop)
    return(result)
  }

  if(!missing(Pmax)) {
    check.1.real(Pmax)
    stopifnot(Pmax > 0)
  }

  if(is.numeric(P) && length(P) == 1 && spatstat.options("fastthin")) {
    ## special fast algorithm for constant probability
    if(!missing(Pmax)) P <- P/Pmax
    if(badprobability(P, TRUE)) stop("P is not a valid probability value")
    result <- vector(mode="list", length=nsim)
    switch(what,
           fate = {
             for(isim in seq_len(nsim)) 
               result[[isim]] <- thinjump(nX, P)
           },
           objects = {
             for(isim in seq_len(nsim)) {
               retain <- thinjump(nX, P)
               if(israwxy) {
                 Y <- list(x=xx[retain], y=yy[retain])
               } else {
                 Y <- X[retain]
                 attr(Y, "parents") <- attr(X, "parents")
                 ## also handle offspring-to-parent map if present
                 if(!is.null(parentid <- attr(X, "parentid")))
                   attr(Y, "parentid") <- parentid[retain]
               }
               result[[isim]] <- Y
             }
           })
    result <- simulationresult(result, nsim, drop)
    return(result)
  }

  #' general case: compute probabilities first
  
  if(is.numeric(P)) {
    ## vector of retention probabilities
    pX <- P
    if(length(pX) != nX) {
      if(length(pX) == 1)
        pX <- rep.int(pX, nX)
      else 
        stop("Length of vector P does not match number of points of X")
    }
  } else if(is.function(P)) {
    ## function - evaluate it at points of X
    if(!(is.ppp(X) || is.lpp(X) || israwxy))
      stop(paste("Don't know how to apply a function to an object of class",
                 commasep(sQuote(class(X)))),
           call.=FALSE)
    pX <- if(inherits(P, c("linfun", "funxy"))) P(X, ...) else P(X$x, X$y, ...)
    if(length(pX) != nX)
      stop("Function P returned a vector of incorrect length")
    if(!is.numeric(pX))
      stop("Function P returned non-numeric values")
  } else if(is.im(P)) {
    ## image - look it up
    if(!(is.ppp(X) || is.lpp(X) || israwxy))
      stop(paste("Don't know how to apply image values to an object of class",
                 commasep(sQuote(class(X)))),
           call.=FALSE)
    if(!(P$type %in% c("integer", "real")))
      stop("Values of image P should be numeric")
    pX <- P[X, drop=FALSE]
  } else stop("Unrecognised format for P")

  if(!all(is.finite(pX))) {
    if(na.zero) {
      pX[is.na(pX)] <- 0
    } else if(anyNA(pX)) {
      if(is.function(P)) stop("Function P returned some NA values")
      if(is.im(P)) stop("Some points lie outside the domain of image P")
      stop("P contains NA's")
    } else {
      if(is.function(P)) stop("Function P returned some NaN or Inf values")
      if(is.im(P)) stop("Image P contains NaN or Inf values")
      stop("P contains NaN or Inf values")
    }
  }

  if(fatal || warn) {
    ## check for bad values of probability
    ra <- range(pX)/Pmax
    if(ra[1] < 0) {
      gripe <- paste("some probabilities are negative",
                     paren(paste("minimum", ra[1])))
      if(fatal) stop(gripe)
      if(warn) stop(gripe)
    }
    if(ra[2] > 1) {
      gripe <- paste("some probabilities are greater than 1",
                     paren(paste("maximum", ra[2])))
      if(fatal) stop(gripe)
      if(warn) warning(gripe)
    }
  }

  #' now simulate
  
  result <- vector(mode="list", length=nsim)
  switch(what,
         fate = {
           for(isim in seq_len(nsim)) 
             result[[isim]] <- ((Pmax * runif(length(pX))) < pX)
         },
         objects = {
           for(isim in seq_len(nsim)) {
             retain <- ((Pmax * runif(length(pX))) < pX)
             if(israwxy) {
               Y <- list(x=xx[retain], y=yy[retain])
             } else {
               Y <- X[retain]
               attr(Y, "parents") <- attr(X, "parents")
               ## also handle offspring-to-parent map if present
               if(!is.null(parentid <- attr(X, "parentid")))
                 attr(Y, "parentid") <- parentid[retain]
             }
             result[[isim]] <- Y
             }
         })
  result <- simulationresult(result, nsim, drop)
  return(result)
}



