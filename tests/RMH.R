#'
#'   Header for all (concatenated) test files
#'
#'   Require spatstat.random
#'   Obtain environment variable controlling tests.
#'
#'   $Revision: 1.5 $ $Date: 2020/04/30 05:31:37 $

require(spatstat.random)
FULLTEST <- (nchar(Sys.getenv("SPATSTAT_TEST", unset="")) > 0)
ALWAYS   <- TRUE
cat(paste("--------- Executing",
          if(FULLTEST) "** ALL **" else "**RESTRICTED** subset of",
          "test code -----------\n"))
#
#  tests/rmhAux.R
#
#  $Revision: 1.2 $  $Date: 2020/05/01 02:42:58 $
#
#  For interactions which maintain 'auxiliary data',
#  verify that the auxiliary data are correctly updated.
#
#  To do this we run rmh with nsave=1 so that the point pattern state
#  is saved after every iteration, then the algorithm is restarted,
#  and the auxiliary data are re-initialised. The final state must agree with
#  the result of simulation without saving.
# ----------------------------------------------------

if(ALWAYS) { # involves C code
local({

   # Geyer:
   mod <- list(cif="geyer",
               par=list(beta=1.25,gamma=1.6,r=0.2,sat=4.5),
               w=square(10))

   set.seed(42)
   X.nosave <- rmh(model=mod,
                   start=list(n.start=50),
                   control=list(nrep=1e3, periodic=FALSE, expand=1))
   set.seed(42)
   X.save <- rmh(model=mod,
                 start=list(n.start=50),
                 control=list(nrep=1e3, periodic=FALSE, expand=1,
                   nburn=0, nsave=1, pstage="start"))
   #' Need to set pstage='start' so that proposals are generated
   #' at the start of the procedure in both cases.

   stopifnot(npoints(X.save) == npoints(X.nosave))
   stopifnot(max(nncross(X.save, X.nosave)$dist) == 0)
   stopifnot(max(nncross(X.nosave, X.save)$dist) == 0)
})
}
##
##   tests/rmhBasic.R
##
##   $Revision: 1.23 $  $Date: 2020/05/01 02:42:58 $
#
# Test examples for rmh.default
# run to reasonable length
# and with tests for validity added
# ----------------------------------------------------

local({

  if(!exists("nr") || is.null(nr)) nr <- 1000
  nrlong <- 2e3
  spatstat.options(expand=1.05)

  if(ALWAYS) {  ## fundamental C code
    ## Strauss process.
    mod01 <- list(cif="strauss",
                  par=list(beta=2,gamma=0.2,r=0.7),
                  w=c(0,10,0,10))
    X1.strauss <- rmh(model=mod01,
                      start=list(n.start=80),
                      control=list(nrep=nr))
    X1.strauss2 <- rmh(model=mod01,
                       start=list(n.start=80),
                       control=list(nrep=nr, periodic=FALSE))

    ## Strauss process, conditioning on n = 80:
    X2.strauss <- rmh(model=mod01,start=list(n.start=80),
                      control=list(p=1,nrep=nr))
    stopifnot(npoints(X2.strauss) == 80)

    ## test tracking mechanism
    X1.strauss <- rmh(model=mod01,start=list(n.start=80),
                      control=list(nrep=nr), track=TRUE)
    X2.strauss <- rmh(model=mod01,start=list(n.start=80),
                      control=list(p=1,nrep=nr), track=TRUE)
   
    ## Hard core process:
    mod02 <- list(cif="hardcore",par=list(beta=2,hc=0.7),w=c(0,10,0,10))
    X3.hardcore <- rmh(model=mod02,start=list(n.start=60),
                       control=list(nrep=nr))
    X3.hardcore2 <- rmh(model=mod02,start=list(n.start=60),
                        control=list(nrep=nr, periodic=FALSE))

    ## Strauss process equal to pure hardcore:
    mod02 <- list(cif="strauss",par=list(beta=2,gamma=0,r=0.7),w=c(0,10,0,10))
    X3.strauss <- rmh(model=mod02,start=list(n.start=60),
                      control=list(nrep=nr))
   
    ## Strauss process in a polygonal window.
    x     <- c(0.55,0.68,0.75,0.58,0.39,0.37,0.19,0.26,0.42)
    y     <- c(0.20,0.27,0.68,0.99,0.80,0.61,0.45,0.28,0.33)
    mod03 <- list(cif="strauss",par=list(beta=2000,gamma=0.6,r=0.07),
                  w=owin(poly=list(x=x,y=y)))
    X4.strauss <- rmh(model=mod03,start=list(n.start=90),
                      control=list(nrep=nr))
   
    ## Strauss process in a polygonal window, conditioning on n = 42.
    X5.strauss <- rmh(model=mod03,start=list(n.start=42),
                      control=list(p=1,nrep=nr))
    stopifnot(npoints(X5.strauss) == 42)

    ## Strauss process, starting off from X4.strauss, but with the
    ## polygonal window replace by a rectangular one.  At the end,
    ## the generated pattern is clipped to the original polygonal window.
    xxx <- X4.strauss
    xxx$window <- as.owin(c(0,1,0,1))
    X6.strauss <- rmh(model=mod03,start=list(x.start=xxx),
                      control=list(nrep=nr))
   
    ## Strauss with hardcore:
    mod04 <- list(cif="straush",par=list(beta=2,gamma=0.2,r=0.7,hc=0.3),
                  w=c(0,10,0,10))
    X1.straush <- rmh(model=mod04,start=list(n.start=70),
                      control=list(nrep=nr))
    X1.straush2 <- rmh(model=mod04,start=list(n.start=70),
                       control=list(nrep=nr, periodic=FALSE))
   
    ## Another Strauss with hardcore (with a perhaps surprising result):
    mod05 <- list(cif="straush",par=list(beta=80,gamma=0.36,r=45,hc=2.5),
                  w=c(0,250,0,250))
    X2.straush <- rmh(model=mod05,start=list(n.start=250),
                      control=list(nrep=nr))
   
    ## Pure hardcore (identical to X3.strauss).
    mod06 <- list(cif="straush",par=list(beta=2,gamma=1,r=1,hc=0.7),
                  w=c(0,10,0,10))
    X3.straush <- rmh(model=mod06,start=list(n.start=60),
                      control=list(nrep=nr))

    ## Fiksel
    modFik <- list(cif="fiksel",
                   par=list(beta=180,r=0.15,hc=0.07,kappa=2,a= -1.0),
                   w=square(1))
    X.fiksel <- rmh(model=modFik,start=list(n.start=10),
                    control=list(nrep=nr))
    X.fiksel2 <- rmh(model=modFik,start=list(n.start=10),
                     control=list(nrep=nr,periodic=FALSE))

    ## Penttinen process:
    modpen <- rmhmodel(cif="penttinen",par=list(beta=2,gamma=0.6,r=1),
                       w=c(0,10,0,10))
    X.pen <- rmh(model=modpen,start=list(n.start=10),
                 control=list(nrep=nr))
    X.pen2 <- rmh(model=modpen,start=list(n.start=10),
                  control=list(nrep=nr, periodic=FALSE))
    ## equivalent to hardcore
    modpen$par$gamma <- 0
    X.penHard <- rmh(model=modpen,start=list(n.start=3),
                     control=list(nrep=nr))

    ## Area-interaction, inhibitory
    mod.area <- list(cif="areaint",
                     par=list(beta=2,eta=0.5,r=0.5),
                     w=square(10))
    X.area <- rmh(model=mod.area,start=list(n.start=60),
                  control=list(nrep=nr))
    X.areaE <- rmh(model=mod.area,start=list(n.start=60),
                   control=list(nrep=nr, periodic=FALSE))

    ## Area-interaction, clustered
    mod.area2 <- list(cif="areaint", par=list(beta=2,eta=1.5,r=0.5),
                      w=square(10))
    X.area2 <- rmh(model=mod.area2,start=list(n.start=60),
                   control=list(nrep=nr))

    ## Area-interaction close to hard core
    set.seed(42)
    mod.area0 <- list(cif="areaint",par=list(beta=2,eta=1e-300,r=0.35),
                      w=square(10))
    X.area0 <- rmh(model=mod.area0,start=list(x.start=X3.hardcore),
                   control=list(nrep=nrlong))
    stopifnot(nndist(X.area0) > 0.6)
   
    ## Soft core:
    w    <- c(0,10,0,10)
    mod07 <- list(cif="sftcr",par=list(beta=0.8,sigma=0.1,kappa=0.5),
                  w=c(0,10,0,10))
    X.sftcr <- rmh(model=mod07,start=list(n.start=70),
                   control=list(nrep=nr))
    X.sftcr2 <- rmh(model=mod07,start=list(n.start=70),
                    control=list(nrep=nr, periodic=FALSE))
   
    ## Diggle, Gates, and Stibbard:
    mod12 <- list(cif="dgs",par=list(beta=3600,rho=0.08),w=c(0,1,0,1))
    X.dgs <- rmh(model=mod12,start=list(n.start=300),
                 control=list(nrep=nr))
    X.dgs2 <- rmh(model=mod12,start=list(n.start=300),
                  control=list(nrep=nr, periodic=FALSE))
   
    ## Diggle-Gratton:
    mod13 <- list(cif="diggra",
                  par=list(beta=1800,kappa=3,delta=0.02,rho=0.04),
                  w=square(1))
    X.diggra <- rmh(model=mod13,start=list(n.start=300),
                    control=list(nrep=nr))
    X.diggra2 <- rmh(model=mod13,start=list(n.start=300),
                     control=list(nrep=nr, periodic=FALSE))
   
    ## Geyer:
    mod14 <- list(cif="geyer",par=list(beta=1.25,gamma=1.6,r=0.2,sat=4.5),
                  w=c(0,10,0,10))
    X1.geyer <- rmh(model=mod14,start=list(n.start=200),
                    control=list(nrep=nr))
   
    ## Geyer; same as a Strauss process with parameters
    ## (beta=2.25,gamma=0.16,r=0.7):
    mod15 <- list(cif="geyer",par=list(beta=2.25,gamma=0.4,r=0.7,sat=10000),
                  w=c(0,10,0,10))
    X2.geyer <- rmh(model=mod15,start=list(n.start=200),
                    control=list(nrep=nr))
    X2.geyer2 <- rmh(model=mod15,start=list(n.start=200),
                     control=list(nrep=nr, periodic=FALSE))
   
    mod16 <- list(cif="geyer",par=list(beta=8.1,gamma=2.2,r=0.08,sat=3))
    X3.geyer <- rmh(model=mod16,start=list(x.start=redwood),
                    control=list(periodic=TRUE,nrep=nr))
    X3.geyer2 <- rmh(model=mod16,start=list(x.start=redwood),
                     control=list(periodic=FALSE,nrep=nr))
   
    ## Geyer, starting from the redwood data set, simulating
    ## on a torus, and conditioning on n:
    X4.geyer <- rmh(model=mod16,start=list(x.start=redwood),
                    control=list(p=1,periodic=TRUE,nrep=nr))

    ## Lookup (interaction function h_2 from page 76, Diggle (2003)):
    r <- seq(from=0,to=0.2,length=101)[-1] # Drop 0.
    h <- 20*(r-0.05)
    h[r<0.05] <- 0
    h[r>0.10] <- 1
    mod17 <- list(cif="lookup",par=list(beta=4000,h=h,r=r),w=c(0,1,0,1))
    X.lookup <- rmh(model=mod17,start=list(n.start=100),
                    control=list(nrep=nr, periodic=TRUE))
    X.lookup2 <- rmh(model=mod17,start=list(n.start=100),
                     control=list(nrep=nr, expand=1, periodic=FALSE))
    ## irregular
    mod17x <- mod17
    mod17x$par$r <- 0.05*sqrt(mod17x$par$r/0.05)
    X.lookupX <- rmh(model=mod17x,start=list(n.start=100),
                     control=list(nrep=nr, periodic=TRUE))
    X.lookupX2 <- rmh(model=mod17x,start=list(n.start=100),
                      control=list(nrep=nr, expand=1, periodic=FALSE))

    ## Strauss with trend
    tr <- function(x,y){x <- x/250; y <- y/250;
      exp((6*x + 5*y - 18*x^2 + 12*x*y - 9*y^2)/6)
    }
    beta <- 0.3
    gmma <- 0.5
    r    <- 45
    tr3   <- function(x,y){x <- x/250; y <- y/250;
      exp((6*x + 5*y - 18*x^2 + 12*x*y - 9*y^2)/6)
    }
    ## log quadratic trend
    mod17 <- list(cif="strauss",
                  par=list(beta=beta,gamma=gmma,r=r),w=c(0,250,0,250),
                  trend=tr3)
    X1.strauss.trend <- rmh(model=mod17,start=list(n.start=90),
                            control=list(nrep=nr))

    #' trend is an image
    mod18 <- mod17
    mod18$trend <- as.im(mod18$trend, square(10))
    X1.strauss.trendim <- rmh(model=mod18,start=list(n.start=90),
                              control=list(nrep=nr))

  }
  if(FULLTEST) {
    #'.....  Test other code blocks .................

    #' argument passing to rmhcontrol
    X1S <- rmh(model=mod01, control=NULL, nrep=nr)
    X1f <- rmh(model=mod01, fixall=TRUE,  nrep=nr) # issues a warning
  }

  if(ALWAYS) {
    #'  nsim > 1
    Xlist <- rmh(model=mod01,start=list(n.start=80),
                 control=list(nrep=nr),
                 nsim=2)
    #' Condition on contents of window
    XX <- Xlist[[1]]
    YY <- XX[square(2)]
    XXwindow <- rmh(model=mod01, start=list(n.start=80),
                    control=list(nrep=nr, x.cond=YY))
    XXwindowTrend <- rmh(model=mod17, start=list(n.start=80),
                         control=list(nrep=nr, x.cond=YY))

    #' Palm conditioning
    XXpalm <- rmh(model=mod01,start=list(n.start=80),
                  control=list(nrep=nr, x.cond=coords(YY)))
    XXpalmTrend <- rmh(model=mod17,start=list(n.start=80),
                       control=list(nrep=nr, x.cond=coords(YY)))

    #' nsave, nburn
    chq <- function(X) {
      Xname <- deparse(substitute(X))
      A <- attr(X, "saved")
      if(length(A) == 0)
        stop(paste(Xname, "did not include a saved list of patterns"))
      return("ok")
    }
    XXburn <- rmh(model=mod01,start=list(n.start=80), verbose=FALSE,
                  control=list(nrep=nr, nsave=500, nburn=100))
    chq(XXburn)
    XXburnTrend <- rmh(model=mod17,start=list(n.start=80), verbose=FALSE,
                       control=list(nrep=nr, nsave=500, nburn=100))
    chq(XXburnTrend)
    XXburn0 <- rmh(model=mod01,start=list(n.start=80), verbose=FALSE,
                   control=list(nrep=nr, nsave=500, nburn=0))
    chq(XXburn0)
    XXsaves <- rmh(model=mod01,start=list(n.start=80), verbose=FALSE,
                   control=list(nrep=nr, nsave=c(500, 200)))
    chq(XXsaves)
    XXsaves0 <- rmh(model=mod01,start=list(n.start=80), verbose=FALSE,
                    control=list(nrep=nr, nsave=c(500, 200), nburn=0))
    chq(XXsaves0)
  }

  if(FULLTEST) {
    #' code blocks for various interactions, not otherwise tested
    rr <- seq(0,0.2,length=8)[-1]
    gmma <- c(0.5,0.6,0.7,0.8,0.7,0.6,0.5)
    mod18 <- list(cif="badgey",par=list(beta=4000, gamma=gmma,r=rr,sat=5),
                  w=square(1))
    Xbg <- rmh(model=mod18,start=list(n.start=20),
               control=list(nrep=1e4, periodic=TRUE))
    Xbg2 <- rmh(model=mod18,start=list(n.start=20),
                control=list(nrep=1e4, periodic=FALSE))
    #' supporting classes
    rs <- rmhstart()
    print(rs)
    rs <- rmhstart(x.start=cells)
    print(rs)
    rc <- rmhcontrol(x.cond=as.list(as.data.frame(cells)))
    print(rc)
    rc <- rmhcontrol(x.cond=as.data.frame(cells)[FALSE, , drop=FALSE])
    print(rc)
    rc <- rmhcontrol(nsave=100, ptypes=c(0.7, 0.3), x.cond=amacrine)
    print(rc)
    rc <- rmhcontrol(ptypes=c(0.7, 0.3), x.cond=as.data.frame(amacrine))
    print(rc)
  }

})
reset.spatstat.options()
##
##     tests/rmhErrors.R
##
##     $Revision: 1.6 $ $Date: 2020/05/01 02:42:58 $
##
# Things which should cause an error

if(ALWAYS) {
  local({
    if(!exists("nv")) nv <- 0
    if(!exists("nr")) nr <- 1e3
    ## Strauss with zero intensity and p = 1
    mod0S <- list(cif="strauss",par=list(beta=0,gamma=0.6,r=0.7), w = square(3))
    out <- try(X0S <- rmh(model=mod0S,start=list(n.start=80),
                          control=list(p=1,nrep=nr,nverb=nv),verbose=FALSE))
    if(!inherits(out, "try-error"))
      stop("Error not trapped (Strauss with zero intensity and p = 1) in tests/rmhErrors.R")
  })
}



#
# tests/rmhExpand.R
#
# test decisions about expansion of simulation window
#
#  $Revision: 1.9 $  $Date: 2022/10/23 01:17:33 $
#

local({
  if(FULLTEST) {
    ## rmhexpand class 
    a <- summary(rmhexpand(area=2))
    print(a)
    b <- summary(rmhexpand(length=4))
    print(b)
    print(summary(rmhexpand(distance=2)))
    print(summary(rmhexpand(square(2))))
  }
})



#
#  tests/rmhMulti.R
#
#  tests of rmh.default, running multitype point processes
#
#   $Revision: 1.17 $  $Date: 2022/01/05 02:07:32 $

local({
  if(!exists("nr"))  nr <- 2e3
  if(!exists("nv"))  nv <- 0
  spatstat.options(expand=1.05)

  if(FULLTEST) {
    ## Multitype Poisson
    modp2 <- list(cif="poisson",
                  par=list(beta=2), types=letters[1:3], w = square(10))
    Xp2 <- rmh(modp2, start=list(n.start=0), control=list(p=1))

    ## Multinomial 
    Xp2fix <- rmh(modp2, start=list(n.start=c(10,20,30)),
                  control=list(fixall=TRUE, p=1))
    Xp2fixr <- rmh(modp2, start=list(x.start=Xp2fix),
                   control=list(fixall=TRUE, p=1))
  }

  if(ALWAYS) { ## Gibbs models => C code
  
    ## Multitype Strauss:
    beta <- c(0.027,0.008)
    gmma <- matrix(c(0.43,0.98,0.98,0.36),2,2)
    r    <- matrix(c(45,45,45,45),2,2)
    mod08 <- list(cif="straussm",par=list(beta=beta,gamma=gmma,radii=r),
                  w=c(0,250,0,250))
    X1.straussm <- rmh(model=mod08,start=list(n.start=80),
                       control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv))
   
    ## Multitype Strauss equivalent to hard core:
    mod08hard <- mod08
    mod08hard$par$gamma[] <- 0
    X1.straussm.Hard <- rmh(model=mod08hard,start=list(n.start=20),
                            control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv),
                            periodic=FALSE)
    X1.straussmP.Hard <- rmh(model=mod08hard,start=list(n.start=20),
                             control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv),
                             periodic=TRUE)
   
    ## Multitype Strauss conditioning upon the total number
    ## of points being 80:
    X2.straussm <- rmh(model=mod08,start=list(n.start=80),
                       control=list(p=1,ptypes=c(0.75,0.25),nrep=nr,
                                    nverb=nv))
    stopifnot(X2.straussm$n == 80)

    ## Conditioning upon the number of points of type 1 being 60
    ## and the number of points of type 2 being 20:
    X3.straussm <- rmh(model=mod08,start=list(n.start=c(60,20)),
                       control=list(fixall=TRUE,p=1,ptypes=c(0.75,0.25),
                                    nrep=nr,nverb=nv))
    stopifnot(all(table(X3.straussm$marks) == c(60,20)))

    ## Multitype hardcore:
    rhc  <- matrix(c(9.1,5.0,5.0,2.5),2,2)
    mod087 <- list(cif="multihard",par=list(beta=5*beta,hradii=rhc),
                   w=square(12))
    cheque <- function(X, r) {
      Xname <- deparse(substitute(X))
      nn <- minnndist(X, by=marks(X))
      print(nn)
      if(!all(nn >= r, na.rm=TRUE))
        stop(paste(Xname, "violates hard core constraint"), call.=FALSE)
      return(invisible(NULL))
    }
    #' make an initial state that violates hard core
    #' (cannot use 'x.start' here because it disables thinning)
    #' and check that result satisfies hard core
    set.seed(19171025)
    X.multihard.close <- rmh(model=mod087,start=list(n.start=100),
                             control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv),
                             periodic=FALSE)
    cheque(X.multihard.close, rhc)
    X.multihard.closeP <- rmh(model=mod087,start=list(n.start=100),
                              control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv,
                                           periodic=TRUE))
    cheque(X.multihard.closeP, rhc)

    ## Multitype Strauss hardcore:
    mod09 <- list(cif="straushm",
                  par=list(beta=5*beta,gamma=gmma,
                           iradii=r,hradii=rhc),w=square(12))
    X.straushm <- rmh(model=mod09,start=list(n.start=100),
                      control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv),
                      periodic=FALSE)
    X.straushmP <- rmh(model=mod09,start=list(n.start=100),
                       control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv,
                                    periodic=TRUE))

    ## Multitype Strauss hardcore equivalent to multitype hardcore:
    mod09hard <- mod09
    mod09hard$par$gamma[] <- 0
    X.straushm.hard <- rmh(model=mod09hard,start=list(n.start=15),
                           control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv,
                                        periodic=FALSE))
    X.straushmP.hard <- rmh(model=mod09hard,start=list(n.start=15),
                            control=list(ptypes=c(0.75,0.25),nrep=nr,nverb=nv),
                            periodic=TRUE)

    ## Multitype Strauss hardcore with trends for each type:
    beta  <- c(0.27,0.08)
    tr3   <- function(x,y){x <- x/250; y <- y/250;
      exp((6*x + 5*y - 18*x^2 + 12*x*y - 9*y^2)/6)
    } # log quadratic trend
    tr4   <- function(x,y){x <- x/250; y <- y/250; exp(-0.6*x+0.5*y)}
                        # log linear trend
    mod10 <- list(cif="straushm",
                  par=list(beta=beta,gamma=gmma,
                           iradii=r,hradii=rhc),w=c(0,250,0,250),
                  trend=list(tr3,tr4))
    X1.straushm.trend <- rmh(model=mod10,start=list(n.start=350),
                             control=list(ptypes=c(0.75,0.25),
                                          nrep=nr,nverb=nv))
   
    ## Multitype Strauss hardcore with trends for each type, given as images:
    bigwin <- square(250)
    i1 <- as.im(tr3, bigwin)
    i2 <- as.im(tr4, bigwin)
    mod11 <- list(cif="straushm",par=list(beta=beta,gamma=gmma,
                                          iradii=r,hradii=rhc),w=bigwin,
                  trend=list(i1,i2))
    X2.straushm.trend <- rmh(model=mod11,start=list(n.start=350),
                             control=list(ptypes=c(0.75,0.25),expand=1,
                                          nrep=nr,nverb=nv))

    #' nsave, nburn
    chq <- function(X) {
      Xname <- deparse(substitute(X))
      A <- attr(X, "saved")
      if(length(A) == 0)
        stop(paste(Xname, "did not include a saved list of patterns"))
      return("ok")
    }
    XburnMS <- rmh(model=mod08,start=list(n.start=80), verbose=FALSE,
                   control=list(ptypes=c(0.75,0.25),
                                nrep=nr,nsave=500, nburn=100))
    chq(XburnMS)
    XburnMStrend <- rmh(model=mod10,start=list(n.start=350), verbose=FALSE,
                        control=list(ptypes=c(0.75,0.25),
                                     nrep=nr,nsave=500, nburn=100))
    chq(XburnMStrend)

    
#######################################################################
############  checks on distribution of output  #######################
#######################################################################

    checkp <- function(p, context, testname, failmessage, pcrit=0.01) {
      if(missing(failmessage))
        failmessage <- paste("output failed", testname)
      if(p < pcrit)
        warning(paste(context, ",",  failmessage), call.=FALSE)
      cat(paste("\n", context, ",", testname, "has p-value", signif(p,4), "\n"))
    }

    ## Multitype Strauss code; output is multitype Poisson

    beta  <- 100 * c(1,1)
    ri    <- matrix(0.07, 2, 2)
    gmma  <- matrix(1, 2, 2)  # no interaction
    tr1   <- function(x,y){ rep(1, length(x)) }
    tr2   <- function(x,y){ rep(2, length(x)) }
    mod <- rmhmodel(cif="straussm",
                    par=list(beta=beta,gamma=gmma,radii=ri),
                    w=owin(),
                    trend=list(tr1,tr2))

    X <- rmh(mod, start=list(n.start=0), control=list(nrep=1e6))

    ## The model is Poisson with intensity 100 for type 1 and 200 for type 2.
    ## Total number of points is Poisson (300)
    ## Marks are i.i.d. with P(type 1) = 1/3, P(type 2) = 2/3.
    
    ## Test whether the total intensity looks right
    ##
    p <- ppois(X$n, 300)
    p.val <- 2 * min(p, 1-p)
    checkp(p.val, 
           "In multitype Poisson simulation",
           "test whether total number of points has required mean value")

    ## Test whether the mark distribution looks right
    ta <- table(X$marks)
    cat("Frequencies of marks:")
    print(ta)
    checkp(chisq.test(ta, p = c(1,2)/3)$p.value,
           "In multitype Poisson simulation",
           "chi-squared goodness-of-fit test for mark distribution (1/3, 2/3)")

#####
####  multitype Strauss code; fixall=TRUE;
####  output is multinomial process with nonuniform locations
####

    the.context <- "In nonuniform multinomial simulation"

    beta  <- 100 * c(1,1)
    ri    <- matrix(0.07, 2, 2)
    gmma  <- matrix(1, 2, 2)  # no interaction
    tr1   <- function(x,y){ ifelse(x < 0.5, 0, 2) } 
    tr2   <- function(x,y){ ifelse(y < 0.5, 1, 3) }
    ## cdf of these distributions
    Fx1 <- function(x) { ifelse(x < 0.5, 0, ifelse(x < 1, 2 * x - 1, 1)) }
    Fy2 <- function(y) { ifelse(y < 0, 0,
                         ifelse(y < 0.5, y/2,
                         ifelse(y < 1, (1/2 + 3 * (y-1/2))/2, 1))) }
                                                               

    mod <- rmhmodel(cif="straussm",
                    par=list(beta=beta,gamma=gmma,radii=ri),
                    w=owin(),
                    trend=list(tr1,tr2))

    X <- rmh(mod, start=list(n.start=c(50,50)),
             control=list(nrep=1e6, expand=1, p=1, fixall=TRUE))

    ## The model is Poisson 
    ## Mean number of type 1 points = 100
    ## Mean number of type 2 points = 200
    ## Total intensity = 300
    ## Marks are i.i.d. with P(type 1) = 1/3, P(type 2) = 2/3

    ## Test whether the coordinates look OK
    Y <- split(X)
    X1 <- Y[[names(Y)[1]]]
    X2 <- Y[[names(Y)[2]]]
    checkp(ks.test(X1$y, "punif")$p.value,
           the.context,
           "Kolmogorov-Smirnov test of uniformity of y coordinates of type 1 points")
    if(any(X1$x < 0.5)) {
      stop(paste(the.context, ",", 
                 "x-coordinates of type 1 points are IMPOSSIBLE"), call.=FALSE)
    } else {
      checkp(ks.test(Fx1(X1$x), "punif")$p.value,
             the.context,
             "Kolmogorov-Smirnov test of uniformity of transformed x coordinates of type 1 points")
    }
    checkp(ks.test(X2$x, "punif")$p.value,
           the.context,
           "Kolmogorov-Smirnov test of uniformity of x coordinates of type 2 points")
    checkp(ks.test(Fy2(X2$y), "punif")$p.value,
           the.context,
           "Kolmogorov-Smirnov test of uniformity of transformed y coordinates of type 2 points")
  }
  
})

reset.spatstat.options()
#
#   tests/rmhWeird.R
#
#   $Revision: 1.5 $  $Date: 2022/01/05 02:08:29 $
#
#   Test strange boundary cases in rmh.default

local({
   if(!exists("nv"))  nv <- 0
   if(!exists("nr"))  nr <- 2e3

   if(FULLTEST) {
     ## Poisson process
     cat("Poisson\n")
     modP <- list(cif="poisson",par=list(beta=10), w = square(3))
     XP <- rmh(model = modP,
               start = list(n.start=25),
               control=list(nrep=nr,nverb=nv))
   }

   if(ALWAYS) {
     ## Poisson process case of Strauss
     cat("\nPoisson case of Strauss\n")
     modPS <- list(cif="strauss",par=list(beta=10,gamma=1,r=0.7), w = square(3))
     XPS <- rmh(model=modPS,
                start=list(n.start=25),
                control=list(nrep=nr,nverb=nv))
   
     ## Strauss with zero intensity
     cat("\nStrauss with zero intensity\n")
     mod0S <- list(cif="strauss",
                   par=list(beta=0,gamma=0.6,r=0.7), w = square(3))
     X0S   <- rmh(model=mod0S,start=list(n.start=80),
                  control=list(nrep=nr,nverb=nv))
     stopifnot(X0S$n == 0)
   }

   if(FULLTEST) {
     ## Poisson with zero intensity
     cat("\nPoisson with zero intensity\n")
     mod0P <- list(cif="poisson",par=list(beta=0), w = square(3))
     X0P <- rmh(model = mod0P,
                start = list(n.start=25),
                control=list(nrep=nr,nverb=nv))


     ## Poisson conditioned on zero points
     cat("\nPoisson conditioned on zero points\n")
     modp <- list(cif="poisson",
                  par=list(beta=2), w = square(10))
     Xp <- rmh(modp, start=list(n.start=0), control=list(p=1, nrep=nr))
     stopifnot(Xp$n == 0)

     ## Multitype Poisson conditioned on zero points
     cat("\nMultitype Poisson conditioned on zero points\n")
     modp2 <- list(cif="poisson",
                   par=list(beta=2), types=letters[1:3], w = square(10))
     Xp2 <- rmh(modp2, start=list(n.start=0), control=list(p=1, nrep=nr))
     stopifnot(is.marked(Xp2))
     stopifnot(Xp2$n == 0)

     ## Multitype Poisson conditioned on zero points of each type
     cat("\nMultitype Poisson conditioned on zero points of each type\n")
     Xp2fix <- rmh(modp2, start=list(n.start=c(0,0,0)),
                   control=list(p=1, fixall=TRUE, nrep=nr))
     stopifnot(is.marked(Xp2fix))
     stopifnot(Xp2fix$n == 0)
    
   }
})

#
#    tests/rmhmodelHybrids.R
#
#  Test that rmhmodel.ppm and rmhmodel.default
#  work on Hybrid interaction models
#
#   $Revision: 1.6 $  $Date: 2022/10/23 01:17:56 $
#

if(ALWAYS) { # involves C code
local({
    

  # ............ rmhmodel.default ............................

   modH <- list(cif=c("strauss","geyer"),
                par=list(list(beta=50,gamma=0.5, r=0.1),
                         list(beta=1, gamma=0.7, r=0.2, sat=2)),
                w = square(1))
   rmodH <- rmhmodel(modH)
   rmodH
   reach(rmodH)

  # test handling of Poisson components

   modHP <- list(cif=c("poisson","strauss"),
                 par=list(list(beta=5),
                          list(beta=10,gamma=0.5, r=0.1)),
                 w = square(1))
   rmodHP <- rmhmodel(modHP)
   rmodHP
   reach(rmodHP)

   modPP <- list(cif=c("poisson","poisson"),
                 par=list(list(beta=5),
                          list(beta=10)),
                 w = square(1))
   rmodPP <- rmhmodel(modPP)
   rmodPP
   reach(rmodPP)

})
}

#'
#'   tests/rmhsnoopy.R
#'
#'   Test the rmh interactive debugger
#' 
#'   $Revision: 1.11 $  $Date: 2022/10/23 01:19:00 $

if(ALWAYS) { # may depend on platform
local({
  R <- 0.1
  ## define a model and prepare to simulate
  W <- Window(amacrine)
  t1 <- as.im(function(x,y){exp(8.2+0.22*x)}, W)
  t2 <- as.im(function(x,y){exp(8.3+0.22*x)}, W)
  model <- rmhmodel(cif="strauss",
                    trend=solist(off=t1, on=t2),
                    par=list(gamma=0.47, r=R, beta=c(off=1, on=1)))
  siminfo <- rmh(model, preponly=TRUE)
  Wsim <- siminfo$control$internal$w.sim
  Wclip <- siminfo$control$internal$w.clip
  if(is.null(Wclip)) Wclip <- Window(cells)

  ## determine debugger interface panel geometry
  Xinit <- runifpoint(ex=amacrine)[1:40]
  P <- rmhsnoop(Wsim=Wsim, Wclip=Wclip, R=R,
                xcoords=Xinit$x,
                ycoords=Xinit$y,
                mlevels=levels(marks(Xinit)),
                mcodes=as.integer(marks(Xinit)) - 1L,
                irep=3L, itype=1L,
                proptype=1, proplocn=c(0.5, 0.5), propmark=0, propindx=0,
                numerator=42, denominator=24,
                panel.only=TRUE)
  boxes <- P$boxes
  clicknames <- names(P$clicks)
  boxcentres <- do.call(concatxy, lapply(boxes, centroid.owin))

  ## design a sequence of clicks
  actionsequence <- c("Up", "Down", "Left", "Right",
                      "At Proposal", "Zoom Out", "Zoom In", "Reset",
                      "Accept", "Reject", "Print Info",
                      "Next Iteration", "Next Shift", "Next Death",
                      "Skip 10", "Skip 100", "Skip 1000", "Skip 10,000",
                      "Skip 100,000", "Exit Debugger")
  actionsequence <- match(actionsequence, clicknames)
  actionsequence <- actionsequence[!is.na(actionsequence)]
  xy <- lapply(boxcentres, "[", actionsequence)

  ## queue the click sequence
  spatstat.utils::queueSpatstatLocator(xy$x,xy$y)

  ## go
  rmh(model, snoop=TRUE)
})
}
