\name{rDiggleGratton}
\alias{rDiggleGratton}
\title{Perfect Simulation of the Diggle-Gratton Process}
\description{
  Generate a random pattern of points, a simulated realisation
  of the Diggle-Gratton process, using a perfect simulation algorithm.
}
\usage{
  rDiggleGratton(beta, delta, rho, kappa=1, W = owin(),
                 expand=TRUE, nsim=1, drop=TRUE)
}
\arguments{
  \item{beta}{
    intensity parameter (a positive number).
  }
  \item{delta}{
    hard core distance (a non-negative number).
  }
  \item{rho}{
    interaction range (a number greater than \code{delta}).
  }
  \item{kappa}{
    interaction exponent (a non-negative number).
  }
  \item{W}{
    window (object of class \code{"owin"}) in which to
    generate the random pattern. Currently this must be a rectangular
    window.
  }
  \item{expand}{
    Logical. If \code{FALSE}, simulation is performed
    in the window \code{W}, which must be rectangular.
    If \code{TRUE} (the default), simulation is performed
    on a larger window, and the result is clipped to the original
    window \code{W}.
    Alternatively \code{expand} can be an object of class 
    \code{"rmhexpand"} (see \code{\link[spatstat.random]{rmhexpand}})
    determining the expansion method.
  }
  \item{nsim}{Number of simulated realisations to be generated.}
  \item{drop}{
    Logical. If \code{nsim=1} and \code{drop=TRUE} (the default), the
    result will be a point pattern, rather than a list 
    containing a point pattern.
  }
}
\details{
  This function generates a realisation of the 
  Diggle-Gratton point process in the window \code{W}
  using a \sQuote{perfect simulation} algorithm.

  Diggle and Gratton (1984, pages 208-210)
  introduced the pairwise interaction point
  process with pair potential \eqn{h(t)} of the form
  \deqn{
    h(t) = \left( \frac{t-\delta}{\rho-\delta} \right)^\kappa
    \quad\quad \mbox{  if  } \delta \le t \le \rho
  }{
    h(t) = ((t - delta)/(rho - delta))^kappa, {    } delta <= t <= rho
  }
  with \eqn{h(t) = 0} for \eqn{t < \delta}{t < delta}
  and  \eqn{h(t) = 1} for \eqn{t > \rho}{t > rho}.
  Here \eqn{\delta}{delta}, \eqn{\rho}{rho} and \eqn{\kappa}{kappa}
  are parameters.

  Note that we use the symbol \eqn{\kappa}{kappa}
  where Diggle and Gratton (1984) 
  use \eqn{\beta}{beta}, since in \pkg{spatstat} we reserve the symbol
  \eqn{\beta}{beta} for an intensity parameter.

  The parameters must all be nonnegative,
  and must satisfy \eqn{\delta \le \rho}{delta <= rho}.

  The simulation algorithm used to generate the point pattern
  is \sQuote{dominated coupling from the past}
  as implemented by Berthelsen and \Moller (2002, 2003).
  This is a \sQuote{perfect simulation} or \sQuote{exact simulation}
  algorithm, so called because the output of the algorithm is guaranteed
  to have the correct probability distribution exactly (unlike the
  Metropolis-Hastings algorithm used in \code{\link[spatstat.random]{rmh}}, whose output
  is only approximately correct).

  There is a tiny chance that the algorithm will 
  run out of space before it has terminated. If this occurs, an error
  message will be generated.
}
\value{
  If \code{nsim = 1}, a point pattern (object of class \code{"ppp"}).
  If \code{nsim > 1}, a list of point patterns.
}
\references{
  Berthelsen, K.K. and \Moller, J. (2002)
  A primer on perfect simulation for spatial point processes.
  \emph{Bulletin of the Brazilian Mathematical Society} 33, 351-367.

  Berthelsen, K.K. and \Moller, J. (2003)
  Likelihood and non-parametric Bayesian MCMC inference 
  for spatial point processes based on perfect simulation and
  path sampling. 
  \emph{Scandinavian Journal of Statistics} 30, 549-564.

  Diggle, P.J. and Gratton, R.J. (1984)
  Monte Carlo methods of inference for implicit statistical models.
  \emph{Journal of the Royal Statistical Society, series B}
  \bold{46}, 193 -- 212.

  \Moller, J. and Waagepetersen, R. (2003).
  \emph{Statistical Inference and Simulation for Spatial Point Processes.}
  Chapman and Hall/CRC.
}
\author{
  \adrian
  
  
  based on original code for the Strauss process by 
  Kasper Klitgaard Berthelsen.
}
\examples{
   X <- rDiggleGratton(50, 0.02, 0.07)
   Z <- rDiggleGratton(50, 0.02, 0.07, 2, nsim=2)
}
\seealso{
  \code{\link[spatstat.random]{rmh}},
  \code{\link[spatstat.random]{rStrauss}},
  \code{\link[spatstat.random]{rHardcore}},
  \code{\link[spatstat.random]{rStraussHard}},
  \code{\link[spatstat.random]{rDGS}},
  \code{\link[spatstat.random]{rPenttinen}}.

  For fitting the model, see \code{\link[spatstat.model]{DiggleGratton}}.
}
\keyword{spatial}
\keyword{datagen}
