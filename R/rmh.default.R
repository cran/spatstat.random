#
# $Id: rmh.default.R,v 1.119 2022/05/21 08:53:38 adrian Exp $
#
rmh.default <- function(model,start=NULL,
                        control=default.rmhcontrol(model),
                        ...,
                        nsim=1, drop=TRUE, saveinfo=TRUE,
                        verbose=TRUE, snoop=FALSE) {
#
# Function rmh.  To simulate realizations of 2-dimensional point
# patterns, given the conditional intensity function of the 
# underlying process, via the Metropolis-Hastings algorithm.
#
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
#
#     V A L I D A T E
#
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
  
  if(verbose)
    cat("Checking arguments..")

# validate arguments and fill in the defaults

  model <- rmhmodel(model)
  start <- rmhstart(start)
  if(is.null(control)) {
    control <- default.rmhcontrol(model)
  } else {
    control <- rmhcontrol(control)
  }
  # override 
  if(length(list(...)) > 0)
    control <- update(control, ...)

  control <- rmhResolveControl(control, model)

  saveinfo <- as.logical(saveinfo)

  check.1.integer(nsim)
  stopifnot(nsim >= 0)
  
  # retain "..." arguments unrecognised by rmhcontrol
  # These are assumed to be arguments of functions defining the trend
  argh <- list(...)
  known <- names(argh) %in% names(formals(rmhcontrol.default))
  f.args <- argh[!known]

#### Multitype models
  
# Decide whether the model is multitype; if so, find the types.

  types <- rmhResolveTypes(model, start, control)
  ntypes <- length(types)
  mtype <- (ntypes > 1)

# If the model is multitype, check that the model parameters agree with types
# and digest them
  
  if(mtype && !is.null(model$check)) {
    model <- rmhmodel(model, types=types)
  } else {
    model$types <- types
  }
  
######## Check for illegal combinations of model, start and control  ########

  # No expansion can be done if we are using x.start

  if(start$given == "x") {
    if(control$expand$force.exp)
      stop("Cannot expand window when using x.start.\n", call.=FALSE)
    control$expand <- .no.expansion
  }

# Warn about a silly value of fixall:
  if(control$fixall & ntypes==1) {
    warning("control$fixall applies only to multitype processes. Ignored.",
            call.=FALSE)
    control$fixall <- FALSE
    if(control$fixing == "n.each.type")
      control$fixing <- "n.total"
  }

  
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
#
#     M O D E L   P A R A M E T E R S
#
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===

#######  Determine windows  ################################

  if(verbose)
    cat("determining simulation windows...")
  
# these may be NULL  
  w.model <- model$w
  x.start <- start$x.start
  trend <- model$trend
  trendy <- !is.null(trend)

  singletrend <- trendy && (is.im(trend) ||
                            is.function(trend) ||
                            (is.numeric(trend) && length(trend) == 1))
  trendlist <- if(singletrend) list(trend) else trend
  
# window implied by trend image, if any
  
  w.trend <- 
    if(is.im(trend))
      as.owin(trend)
    else if(is.list(trend) && any(ok <- unlist(lapply(trend, is.im))))
      as.owin((trend[ok])[[1L]])
    else NULL

##  Clipping window (for final result)
  
  w.clip <-
    if(!is.null(w.model))
      w.model
    else if(!will.expand(control$expand)) {
      if(start$given == "x" && is.ppp(x.start))
        x.start$window
      else if(is.owin(w.trend))
        w.trend
    } else NULL

  if(!is.owin(w.clip))
    stop("Unable to determine window for pattern", call.=FALSE)

  
##  Simulation window 

  xpn <- rmhResolveExpansion(w.clip, control, trendlist, "trend")
  w.sim <- xpn$wsim
  expanded <- xpn$expanded

## Check the fine print   

  if(expanded) {

    if(control$fixing != "none")
      stop(paste("If we're conditioning on the number of points,",
                 "we cannot clip the result to another window."),
           call.=FALSE)

    if(!is.subset.owin(w.clip, w.sim))
      stop("Expanded simulation window does not contain model window",
           call.=FALSE)
  }


#######  Trend  ################################
  
# Check that the expanded window fits inside the window
# upon which the trend(s) live if there are trends and
# if any trend is given by an image.

  if(expanded && !is.null(trend)) {
    trends <- if(is.im(trend)) list(trend) else trend
    images <- unlist(lapply(trends, is.im))
    if(any(images)) {
      iwindows <- lapply(trends[images], as.owin)
      nimages <- length(iwindows)
      misfit <- !sapply(iwindows, is.subset.owin, A=w.sim)
      nmisfit <- sum(misfit)
      if(nmisfit > 1) 
        stop(paste("Expanded simulation window is not contained in",
                   "several of the trend windows.\n",
                   "Bailing out."), call.=FALSE)
      else if(nmisfit == 1) {
        warning(paste("Expanded simulation window is not contained in",
                      if(nimages == 1) "the trend window.\n"
                      else "one of the trend windows.\n",
                      "Expanding to this trend window (only)."),
                call.=FALSE)
        w.sim <- iwindows[[which(misfit)]]
      }
    }
  }

# Extract the 'beta' parameters

  if(length(model$cif) == 1) {
    # single interaction
    beta <- model$C.beta
    betalist <- list(beta)
  } else {
    # hybrid
    betalist <- model$C.betalist
    # multiply beta vectors for each component
    beta <- Reduce("*", betalist)
  }
  
##### .................. CONDITIONAL SIMULATION ...................

#####  
#||   Determine windows for conditional simulation
#||
#||      w.state  = window for the full configuration
#||  
#||      w.sim    = window for the 'free' (random) points
#||

  w.state <- w.sim
  
  condtype <- control$condtype
  x.cond   <- control$x.cond
#  n.cond   <- control$n.cond

  switch(condtype,
         none={
           w.cond <- NULL
         },
         window={
           # conditioning on the realisation inside a subwindow
           w.cond <- as.owin(x.cond)
           # subtract from w.sim
           w.sim <- setminus.owin(w.state, w.cond)
           if(is.empty(w.sim))
             stop(paste("Conditional simulation is undefined;",
                        "the conditioning window",
                        sQuote("as.owin(control$x.cond)"),
                        "covers the entire simulation window"), call.=FALSE)
         },
         Palm={
           # Palm conditioning
           w.cond <- NULL
         })

#####  
#||   Convert conditioning points to appropriate format


  x.condpp <- switch(condtype,
                        none=NULL,
                        window=x.cond,
                        Palm=as.ppp(x.cond, w.state))

# validate  
  if(!is.null(x.condpp)) {
    if(mtype) {
      if(!is.marked(x.condpp))
        stop("Model is multitype, but x.cond is unmarked", call.=FALSE)
      if(!isTRUE(all.equal(types, levels(marks(x.condpp)))))
        stop("Types of points in x.cond do not match types in model", call.=FALSE)
    }
  }
  

#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
#
#     S T A R T I N G      S T A T E
#
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===

###################### Starting state data ############################

# whether the initial state should be thinned
  
  thin <- (start$given != "x") && (control$fixing == "none")
  
# There must now be a starting state.
  
  if(start$given == "none") {
    # For conditional simulation, the starting state must be given
    if(condtype != "none")
      stop("No starting state given", call.=FALSE)
    # Determine integral of beta * trend over data window.
    # This is the expected number of points in the reference Poisson process.
    area.w.clip <- area(w.clip)
    if(trendy) {
      tsummaries <- summarise.trend(trend, w=w.clip, a=area.w.clip)
      En <- beta * sapply(tsummaries, getElement, name="integral")
    } else {
      En <- beta * area.w.clip
    }
    # Fix n.start equal to this integral
    n.start <- if(spatstat.options("scalable")) round(En) else ceiling(En)
    start <- rmhstart(n.start=n.start)
  }
  
# In the case of conditional simulation, the start data determine
# the 'free' points (i.e. excluding x.cond) in the initial state.

  switch(start$given,
         none={
           stop("No starting state given", call.=FALSE)
         },
         x = {
           # x.start was given
           # coerce it to a ppp object
           if(!is.ppp(x.start))
             x.start <- as.ppp(x.start, w.state)
           if(condtype == "window") {
             # clip to simulation window
             xs <- x.start[w.sim]
             nlost <- x.start$n - xs$n
             if(nlost > 0) 
               warning(paste(nlost,
                             ngettext(nlost, "point","points"),
                             "of x.start",
                             ngettext(nlost, "was", "were"),
                             "removed because",
                             ngettext(nlost, "it", "they"),
                             "fell in the window of x.cond"),
                       call.=FALSE)
             x.start <- xs
           }
           npts.free <- x.start$n
         },
         n = {
           # n.start was given
           n.start <- start$n.start
           # Adjust the number of points in the starting state in accordance
           # with the expansion that has occurred.  
           if(expanded) {
	     holnum <- if(spatstat.options("scalable")) round else ceiling
             n.start <- holnum(n.start * area(w.sim)/area(w.clip))
           }
           #
           npts.free <- sum(n.start) # The ``sum()'' is redundant if n.start
                                # is scalar; no harm, but.
         },
         stop("Internal error: start$given unrecognized"), call.=FALSE)

#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
#
#     C O N T R O L    P A R A M E T E R S
#
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===

###################  Periodic boundary conditions #########################

  periodic <- control$periodic
  
  if(is.null(periodic)) {
    # undecided. Use default rule
    control$periodic <- periodic <- expanded && is.rectangle(w.state)
  } else if(periodic && !is.rectangle(w.state)) {
    # if periodic is TRUE we have to be simulating in a rectangular window.
    stop("Need rectangular window for periodic simulation.", call.=FALSE)
  }

# parameter passed to C:  
  period <-
    if(periodic)
      c(diff(w.state$xrange), diff(w.state$yrange))
    else
      c(-1,-1)



#### vector of proposal probabilities 

  if(!mtype) 
    ptypes <- 1
  else {
    ptypes <- control$ptypes
    if(is.null(ptypes)) {
      # default proposal probabilities
      ptypes <- if(start$given == "x" && (nx <- npoints(x.start)) > 0) {
        table(marks(x.start, dfok=FALSE))/nx
      } else rep.int(1/ntypes, ntypes)
    } else {
      # Validate ptypes
      if(length(ptypes) != ntypes | sum(ptypes) != 1)
        stop("Argument ptypes is mis-specified.", call.=FALSE)
    }
  } 


  
########################################################################
#  Normalising constant for proposal density
# 
# Integral of trend over the expanded window (or area of window):
# Iota == Integral Of Trend (or) Area.

  area.w.sim <- area(w.sim)
  if(trendy) {
    if(verbose)
      cat("Evaluating trend integral...")
    tsummaries <- summarise.trend(trend, w=w.sim, a=area.w.sim)
    mins  <- sapply(tsummaries, getElement, name="min")
    if(any(mins < 0))
      stop("Trend has negative values", call.=FALSE)
    iota <- sapply(tsummaries, getElement, name="integral")
    tmax <- sapply(tsummaries, getElement, name="max")
  } else {
    iota <- area.w.sim
    tmax <- NULL
  }

  
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
#
#     A.S. EMPTY PROCESS
#
#         for conditional simulation, 'empty' means there are no 'free' points
#  
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===

  a.s.empty <- FALSE
  
#
#  Empty pattern, simulated conditional on n
#  
  if(npts.free == 0 && control$fixing != "none") {
    a.s.empty <- TRUE
    if(verbose) {
      mess <- paste("Initial pattern has 0 random points,",
                    "and simulation is conditional on the number of points -")
      if(condtype == "none")
        warning(paste(mess, "returning an empty pattern"), call.=FALSE)
      else
        warning(paste(mess, "returning a pattern with no random points"), call.=FALSE)
    }
  }

#
#  If beta = 0, the process is almost surely empty
#
  
  if(all(beta < .Machine$double.eps)) {
    if(control$fixing == "none" && condtype == "none") {
      # return empty pattern
      if(verbose)
        warning("beta = 0 implies an empty pattern", call.=FALSE)
      a.s.empty <- TRUE
    } else 
      stop("beta = 0 implies an empty pattern, but we are simulating conditional on a nonzero number of points", call.=FALSE)
  }

#
# If we're conditioning on the contents of a subwindow,
# and the subwindow covers the clipping region,
# the result is deterministic.  

  if(condtype == "window" && is.subset.owin(w.clip, w.cond)) {
    a.s.empty <- TRUE
    warning(paste("Model window is a subset of conditioning window:",
              "result is deterministic"), call.=FALSE)
  }    

#
#  
  if(a.s.empty) {
    # create empty pattern, to be returned
    if(!is.null(x.condpp)) 
      empty <- x.condpp[w.clip]
    else {
      empty <- ppp(numeric(0), numeric(0), window=w.clip)
      if(mtype) {
        vide <- factor(types[integer(0)], levels=types)
        empty <- empty %mark% vide
      }
    }
  }

#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
#
#     PACK UP
#
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===

######### Store decisions

  Model <- model
  Start <- start
  Control <- control

  Model$w <- w.clip
  Model$types <- types
  
  Control$expand <- if(expanded) rmhexpand(w.state) else .no.expansion

  Control$internal <- list(w.sim=w.sim,
                           w.state=w.state,
                           x.condpp=x.condpp,
                           ptypes=ptypes,
                           period=period,
                           thin=thin)

  Model$internal <- list(a.s.empty=a.s.empty,
                         empty=if(a.s.empty) empty else NULL,
                         mtype=mtype,
                         trendy=trendy,
                         betalist=betalist,
                         beta=beta,
                         iota=iota,
                         tmax=tmax)

  Start$internal <- list(npts.free=npts.free)

  InfoList <- list(model=Model, start=Start, control=Control)
  class(InfoList) <- c("rmhInfoList", class(InfoList))

  # go
  if(nsim == 1 && drop) {
    result <- do.call(rmhEngine,
                      append(list(InfoList,
                                  verbose=verbose,
                                  snoop=snoop,
                                  kitchensink=saveinfo),
                             f.args))
  } else {
    result <- vector(mode="list", length=nsim)
    if(verbose) {
      splat("Generating", nsim, "point patterns...")
      pstate <- list()
    }
    subverb <- verbose && (nsim == 1)
    for(isim in seq_len(nsim)) {
      if(verbose) pstate <- progressreport(isim, nsim, state=pstate)
      result[[isim]] <- do.call(rmhEngine,
                                append(list(InfoList,
                                            verbose=subverb,
                                            snoop=snoop,
                                            kitchensink=saveinfo),
                                       f.args))
    }
    if(verbose) splat("Done.\n")
    result <- simulationresult(result, nsim, drop)
  }
  return(result)
}

print.rmhInfoList <- function(x, ...) {
  cat("\nPre-digested Metropolis-Hastings algorithm parameters (rmhInfoList)\n")
  print(as.anylist(x))
}

#---------------  rmhEngine -------------------------------------------
#
# This is the interface to the C code.
#
# InfoList is a list of pre-digested, validated arguments
# obtained from rmh.default.
#
# This function is called by rmh.default to generate one simulated
# realisation of the model.
# It's called repeatedly by ho.engine and qqplot.ppm to generate multiple
# realisations (saving time by not repeating the argument checking
# in rmh.default).

# arguments:  
# kitchensink: whether to tack InfoList on to the return value as an attribute
# preponly: whether to just return InfoList without simulating
#
#   rmh.default digests arguments and calls rmhEngine with kitchensink=T
#
#   qqplot.ppm first gets InfoList by calling rmh.default with preponly=T
#              (which digests the model arguments and calls rmhEngine
#               with preponly=T, returning InfoList),
#              then repeatedly calls rmhEngine(InfoList) to simulate.
#
# -------------------------------------------------------

rmhEngine <- function(InfoList, ...,
                       verbose=FALSE, kitchensink=FALSE,
                       preponly=FALSE, snoop=FALSE,
                       overrideXstart=NULL, overrideclip=FALSE) {
# Internal Use Only!
# This is the interface to the C code.

  if(!inherits(InfoList, "rmhInfoList"))
    stop("data not in correct format for internal function rmhEngine", call.=FALSE)

  
  if(preponly)
    return(InfoList)

  model <- InfoList$model
  start <- InfoList$start
  control <- InfoList$control

  w.sim <- control$internal$w.sim
  w.state <- control$internal$w.state
  w.clip <- model$w

  condtype <- control$condtype
  x.condpp <- control$internal$x.condpp

  types <- model$types
  ntypes <- length(types)
  
  ptypes <- control$internal$ptypes
  period <- control$internal$period

  mtype <- model$internal$mtype

  trend <- model$trend
  trendy <- model$internal$trendy
#  betalist <- model$internal$betalist
  beta <- model$internal$beta
  iota <- model$internal$iota
  tmax <- model$internal$tmax

  npts.free <- start$internal$npts.free

  n.start <- start$n.start
  x.start <- start$x.start

  
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
#
#     E M P T Y   P A T T E R N
#
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===

  if(model$internal$a.s.empty) {
    if(verbose) cat("\n")
    empty <- model$internal$empty
    attr(empty, "info") <- InfoList
    return(empty)
  }
  
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===
#
#     S I M U L A T I O N     
#
#==+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===+===

#############################################
####  
####  Random number seed: initialisation & capture
####  
#############################################  
  
  if(!exists(".Random.seed"))
    runif(1L)

  saved.seed <- .Random.seed
  

#############################################
####  
####  Poisson case
####  
#############################################  
  
  if(is.poisson.rmhmodel(model)) {
    if(verbose) cat("\n")
    intensity <- if(!trendy) beta else model$trend
    Xsim <-
      switch(control$fixing,
             none= {
               # Poisson process 
               if(!mtype)
                 rpoispp(intensity, win=w.sim, ..., warnwin=FALSE)
               else
                 rmpoispp(intensity, win=w.sim, types=types, warnwin=FALSE)
             },
             n.total = {
               # Binomial/multinomial process with fixed total number of points
               if(!mtype) 
                 rpoint(npts.free, intensity, win=w.sim, verbose=verbose)
               else
                 rmpoint(npts.free, intensity, win=w.sim, types=types,
                         verbose=verbose)
             },
             n.each.type = {
               # Multinomial process with fixed number of points of each type
               npts.each <-
                 switch(start$given,
                        n = n.start,
                        x = as.integer(table(marks(x.start, dfok=FALSE))),
  stop("No starting state given; can't condition on fixed number of points", call.=FALSE))
               rmpoint(npts.each, intensity, win=w.sim, types=types,
                       verbose=verbose)
             },
             stop("Internal error: control$fixing unrecognised", call.=FALSE)
             )
    # if conditioning, add fixed points
    if(condtype != "none")
      Xsim <- superimpose(Xsim, x.condpp, W=w.state)
    # clip result to output window
    Xclip <- if(!overrideclip) Xsim[w.clip] else Xsim
    attr(Xclip, "info") <- InfoList
    return(Xclip)
  }

  
########################################################################  
#      M e t r o p o l i s  H a s t i n g s    s i m u l a t i o n
########################################################################

  if(verbose)
    cat("Starting simulation.\nInitial state...")
  

#### Build starting state

  npts.cond  <- if(condtype != "none") x.condpp$n else 0
#  npts.total <- npts.free + npts.cond

#### FIRST generate the 'free' points
  
#### First the marks, if any.
#### The marks must be integers 0 to (ntypes-1) for passing to C

  Ctypes <- if(mtype) 0:(ntypes-1) else 0
  
  Cmarks <-
    if(!mtype)
      0
    else
      switch(start$given,
             n = {
               # n.start given
               if(control$fixing=="n.each.type")
                 rep.int(Ctypes,n.start)
               else
                 sample(Ctypes,npts.free,TRUE,ptypes)
             },
             x = {
               # x.start given
               as.integer(marks(x.start, dfok=FALSE))-1L
             },
             stop("internal error: start$given unrecognised", call.=FALSE)
             )
#
# Then the x, y coordinates
#
  switch(start$given,
         x = {
           x <- x.start$x
           y <- x.start$y
         },
         n = {
           xy <-
             if(!trendy)
               runifpoint(npts.free, w.sim, ...)
             else
               rpoint.multi(npts.free, trend, tmax,
                      factor(Cmarks,levels=Ctypes), w.sim, ...)
           x <- xy$x
           y <- xy$y
         })

## APPEND the free points AFTER the conditioning points

  if(condtype != "none") {
    x <- c(x.condpp$x, x)
    y <- c(x.condpp$y, y)
    if(mtype)
      Cmarks <- c(as.integer(marks(x.condpp))-1L, Cmarks)
  }

  if(!is.null(overrideXstart)) {
    #' override the previous data
    x <- overrideXstart$x
    y <- overrideXstart$y
    if(mtype) Cmarks <- as.integer(marks(overrideXstart))-1L
  }

# decide whether to activate visual debugger
  if(snoop) {
    Xinit <- ppp(x, y, window=w.sim)
    if(mtype) 
      marks(Xinit) <- factor(Cmarks, levels=Ctypes, labels=types)
    if(verbose) cat("\nCreating debugger environment..")
    snoopenv <- rmhSnoopEnv(Xinit=Xinit, Wclip=w.clip, R=reach(model))
    if(verbose) cat("Done.\n")
  } else snoopenv <- "none"

  
#######################################################################
#  Set up C call
######################################################################    

# Determine the name of the cif used in the C code

  C.id <- model$C.id
  ncif <- length(C.id)
  
# Get the parameters in C-ese
    
  ipar <- model$C.ipar
  iparlist <- if(ncif == 1) list(ipar) else model$C.iparlist
  iparlen <- lengths(iparlist)

  beta <- model$internal$beta
  
# Absorb the constants or vectors `iota' and 'ptypes' into the beta parameters
  beta <- (iota/ptypes) * beta
  
# Algorithm control parameters

  p       <- control$p
  q       <- control$q
  nrep    <- control$nrep
#  fixcode <- control$fixcode
#  fixing  <- control$fixing
  fixall  <- control$fixall
  nverb   <- control$nverb
  saving  <- control$saving
  nsave   <- control$nsave
  nburn   <- control$nburn
  track   <- control$track
  thin    <- control$internal$thin
  pstage  <- control$pstage %orifnull% "start"
  if(pstage == "block" && !saving) pstage <- "start"
  temper  <- FALSE
  invertemp <- 1.0

  if(verbose)
    cat("Ready to simulate. ")

  storage.mode(ncif)   <- "integer"
  storage.mode(C.id)   <- "character"
  storage.mode(beta)    <- "double"
  storage.mode(ipar)    <- "double"
  storage.mode(iparlen) <- "integer"
  storage.mode(period) <- "double"
  storage.mode(ntypes) <- "integer"
  storage.mode(nrep)   <- "integer"
  storage.mode(p) <- storage.mode(q) <- "double"
  storage.mode(nverb)  <- "integer"
  storage.mode(x) <- storage.mode(y) <- "double"
  storage.mode(Cmarks) <- "integer"
  storage.mode(fixall) <- "integer"
  storage.mode(npts.cond) <- "integer"
  storage.mode(track) <- "integer"
  storage.mode(thin) <- "integer"
  storage.mode(temper) <- "integer"
  storage.mode(invertemp) <- "double"

  if(pstage == "start" || !saving) {
    #' generate all proposal points now.
    if(verbose)
      cat("Generating proposal points...")

    #' If the pattern is multitype, generate the mark proposals (0 to ntypes-1)
    Cmprop <- if(mtype) sample(Ctypes,nrep,TRUE,prob=ptypes) else 0
    storage.mode(Cmprop) <- "integer"

    #' Generate the ``proposal points'' in the expanded window.
    xy <- if(trendy) {
      rpoint.multi(nrep,trend,tmax,
                   factor(Cmprop, levels=Ctypes),
                   w.sim, ..., warn=FALSE)
    } else runifpoint(nrep, w.sim, warn=FALSE)
    xprop <- xy$x
    yprop <- xy$y
    storage.mode(xprop)  <- storage.mode(yprop) <- "double"
  }
  
  if(!saving) {
    # ////////// Single block /////////////////////////////////

    nrep0 <- 0
    storage.mode(nrep0)  <- "integer"

    # Call the Metropolis-Hastings C code:
    if(verbose)
      cat("Running Metropolis-Hastings.\n")
    out <- .Call(SR_xmethas,
                 ncif,
                 C.id,
                 beta,
                 ipar,
                 iparlen,
                 period,
                 xprop, yprop, Cmprop,
                 ntypes,
                 nrep,
                 p, q,
                 nverb,
                 nrep0,
                 x, y, Cmarks,
                 npts.cond,
                 fixall,
                 track,
                 thin,
                 snoopenv,
                 temper,
                 invertemp,
                 PACKAGE="spatstat.random")
  
    # Extract the point pattern returned from C
    X <- ppp(x=out[[1L]], y=out[[2L]], window=w.state, check=FALSE)
    if(mtype) {
      #' convert integer marks from C to R
      #' then restore original type levels
      marks(X) <- factor(out[[3L]], levels=Ctypes, labels=types)
    }

    # Now clip the pattern to the ``clipping'' window:
    if(!overrideclip && !control$expand$force.noexp)
      X <- X[w.clip]

    # Extract transition history:
    if(track) {
      usedout <- if(mtype) 3 else 2
      proptype <- factor(out[[usedout+1]], levels=1:3,
                         labels=c("Birth", "Death", "Shift"))
      accepted <- as.logical(out[[usedout+2]])
      History <- data.frame(proposaltype=proptype, accepted=accepted)
      if(length(out) >= usedout + 4) {
        # history includes numerator & denominator of Hastings ratio
        numerator <- as.double(out[[usedout + 3]])
        denominator <- as.double(out[[usedout + 4]])
        History <- cbind(History,
                         data.frame(numerator=numerator,
                                    denominator=denominator))
      }
    }
  } else {
    # ////////// Multiple blocks /////////////////////////////////
    ## determine length of each block of simulations
    nsuperblocks <- as.integer(1L + ceiling((nrep - nburn)/sum(nsave)))
    block <- c(nburn, rep.int(nsave, nsuperblocks-1L))
    block <- block[cumsum(block) <= nrep]
    if((tot <- sum(block)) < nrep)
      block <- c(block, nrep-tot)
    block <- block[block >= 1L]
    nblocks <- length(block)
    blockend <- cumsum(block)
    ## set up list to contain the saved point patterns
    Xlist <- vector(mode="list", length=nblocks+1L)
    ## save initial state
    Xinit <- ppp(x=x, y=y, window=w.state, check=FALSE)
    if(mtype) {
      ## convert integer marks from C to R
      ## then restore original type levels
      marks(Xinit) <- factor(Cmarks, levels=Ctypes, labels=types)
    }
    Xlist[[1L]] <- Xinit
    # Call the Metropolis-Hastings C code repeatedly:
    xprev <- x
    yprev <- y
    Cmarksprev <- Cmarks
    #
    thinFALSE <- as.integer(FALSE)
    storage.mode(thinFALSE) <- "integer"
    # ................ loop .........................
    for(I in 1:nblocks) {
      # number of iterations for this block
      nrepI <- block[I]
      storage.mode(nrepI) <- "integer"
      # number of previous iterations
      nrep0 <- if(I == 1) 0 else blockend[I-1]
      storage.mode(nrep0)  <- "integer"
      # Generate or extract proposals
      switch(pstage,
             start = {
               #' extract proposals from previously-generated vectors
               if(verbose)
                 cat("Extracting proposal points...")
               seqI <- 1:nrepI
               xpropI <- xprop[seqI]
               ypropI <- yprop[seqI]
               CmpropI <- Cmprop[seqI]
               storage.mode(xpropI) <- storage.mode(ypropI) <- "double"
               storage.mode(CmpropI) <- "integer"
             },
             block = {
               # generate 'nrepI' random proposals
               if(verbose)
                 cat("Generating proposal points...")
               #' If the pattern is multitype, generate the mark proposals 
               CmpropI <- if(mtype) sample(Ctypes,nrepI,TRUE,prob=ptypes) else 0
               storage.mode(CmpropI) <- "integer"
               #' Generate the ``proposal points'' in the expanded window.
               xy <- if(trendy) {
                 rpoint.multi(nrepI,trend,tmax,
                              factor(CmpropI, levels=Ctypes),
                              w.sim, ..., warn=FALSE)
               } else runifpoint(nrepI, w.sim, warn=FALSE)
               xpropI <- xy$x
               ypropI <- xy$y
               storage.mode(xpropI)  <- storage.mode(ypropI) <- "double"
             })
      # no thinning in subsequent blocks
      if(I > 1) thin <- thinFALSE
      #' call
      if(verbose)
        cat("Running Metropolis-Hastings.\n")
      out <- .Call(SR_xmethas,
                   ncif,
                   C.id,
                   beta,
                   ipar,
                   iparlen,
                   period,
                   xpropI, ypropI, CmpropI,
                   ntypes,
                   nrepI,
                   p, q,
                   nverb,
                   nrep0,
                   xprev, yprev, Cmarksprev,
                   npts.cond,
                   fixall,
                   track,
                   thin,
                   snoopenv,
                   temper,
                   invertemp,
                   PACKAGE="spatstat.random")
      # Extract the point pattern returned from C
      X <- ppp(x=out[[1L]], y=out[[2L]], window=w.state, check=FALSE)
      if(mtype) {
        # convert integer marks from C to R
        # then restore original type levels
        marks(X) <- factor(out[[3L]], levels=Ctypes, labels=types)
      }
      
      # Now clip the pattern to the ``clipping'' window:
      if(!overrideclip && !control$expand$force.noexp)
        X <- X[w.clip]

      # commit to list
      Xlist[[I+1L]] <- X
      
      # Extract transition history:
      if(track) {
        usedout <- if(mtype) 3 else 2
        proptype <- factor(out[[usedout+1]], levels=1:3,
                           labels=c("Birth", "Death", "Shift"))
        accepted <- as.logical(out[[usedout+2]])
        HistoryI <- data.frame(proposaltype=proptype, accepted=accepted)
        if(length(out) >= usedout + 4) {
          # history includes numerator & denominator of Hastings ratio
          numerator <- as.double(out[[usedout + 3]])
          denominator <- as.double(out[[usedout + 4]])
          HistoryI <- cbind(HistoryI,
                            data.frame(numerator=numerator,
                                       denominator=denominator))
        }
        # concatenate with histories of previous blocks
        History <- if(I == 1) HistoryI else rbind(History, HistoryI)
      }

      # update 'previous state'
      xprev <- out[[1L]]
      yprev <- out[[2L]]
      Cmarksprev <- if(!mtype) 0 else out[[3]]
      storage.mode(xprev) <- storage.mode(yprev) <- "double"
      storage.mode(Cmarksprev) <- "integer"

      if(pstage == "start") {
        #' discard used proposals
        xprop <- xprop[-seqI]
        yprop <- yprop[-seqI]
        Cmprop <- Cmprop[-seqI]
      }
    }
    # .............. end loop ...............................
    
    # Result of simulation is final state 'X'
    # Tack on the list of intermediate states
    names(Xlist) <- paste("Iteration", c(0,as.integer(blockend)), sep="_")
    attr(X, "saved") <- as.solist(Xlist)
  }

# Append to the result information about how it was generated.
  if(kitchensink) {
    attr(X, "info") <- InfoList
    attr(X, "seed") <- saved.seed
  }
  if(track)
    attr(X, "history") <- History
  
  return(X)
}


# helper function

summarise.trend <- local({
  # main function
  summarise.trend <- function(trend, w, a=area(w)) {
    tlist <- if(is.function(trend) || is.im(trend)) list(trend) else trend
    return(lapply(tlist, summarise1, w=w, a=a))
  }
  # 
  summarise1 <-  function(x, w, a) {
    if(is.numeric(x)) {
      mini <- maxi <- x
      integ <- a*x
    } else {
      Z  <- as.im(x, w)[w, drop=FALSE]
      ran <- range(Z)
      mini <- ran[1L]
      maxi <- ran[2L]
      integ <- integral.im(Z)
    }
    return(list(min=mini, max=maxi, integral=integ))
  }
  summarise.trend
})
  
