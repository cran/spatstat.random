\name{rCauchy}
\alias{rCauchy}
\title{Simulate Neyman-Scott Point Process with Cauchy cluster kernel}
\description{
  Generate a random point pattern, a simulated realisation of the
  Neyman-Scott process with Cauchy cluster kernel.
}
\usage{
 rCauchy(kappa, scale, mu, win = owin(), thresh = 0.001,
         nsim=1, drop=TRUE, 
         saveLambda=FALSE, expand = NULL, \dots,
         poisthresh=1e-6, nonempty=TRUE, saveparents=TRUE)
}
\arguments{
  \item{kappa}{
    Intensity of the Poisson process of cluster centres.
    A single positive number, a function, or a pixel image.
  }
  \item{scale}{
    Scale parameter for cluster kernel. Determines the size of clusters.
    A positive number, in the same units as the spatial coordinates.
  }
  \item{mu}{
    Mean number of points per cluster (a single positive number)
    or reference intensity for the cluster points (a function or
    a pixel image).
  }
  \item{win}{
    Window in which to simulate the pattern.
    An object of class \code{"owin"}
    or something acceptable to \code{\link[spatstat.geom]{as.owin}}.
  }
  \item{thresh}{
    Threshold relative to the cluster kernel value at the origin (parent
    location) determining when the cluster kernel will be treated as
    zero for simulation purposes. Will be overridden by argument
    \code{expand} if that is given.
  }
  \item{nsim}{Number of simulated realisations to be generated.}
  \item{drop}{
    Logical. If \code{nsim=1} and \code{drop=TRUE} (the default), the
    result will be a point pattern, rather than a list 
    containing a point pattern.
  }
  \item{saveLambda}{
    Logical. If \code{TRUE} then the random intensity corresponding to
    the simulated parent points will also be calculated and saved,
    and returns as an attribute of the point pattern.
  }
  \item{expand}{
    Numeric. Size of window expansion for generation of parent
    points. By default determined by calling
    \code{\link[spatstat.random]{clusterradius}} with the numeric threshold value given
    in \code{thresh}.
  }
  \item{\dots}{
    Passed to \code{\link[spatstat.random]{clusterfield}} to control the image resolution
    when \code{saveLambda=TRUE} and to \code{\link[spatstat.random]{clusterradius}} when
    \code{expand} is missing or \code{NULL}.
  }
  \item{poisthresh}{
    Numerical threshold below which the model will be treated
    as a Poisson process. See Details.
  }
  \item{nonempty}{
    Logical. If \code{TRUE} (the default), a more efficient algorithm is
    used, in which parents are generated conditionally on having at
    least one offspring point. If \code{FALSE}, parents are generated
    even if they have no offspring. Both choices are valid; the default
    is recommended unless you need to simulate all the parent points
    for some other purpose.
  }
  \item{saveparents}{
    Logical value indicating whether to save the locations of the
    parent points as an attribute.
  }
}
\value{
  A point pattern (an object of class \code{"ppp"}) if \code{nsim=1},
  or a list of point patterns if \code{nsim > 1}.

  Additionally, some intermediate results of the simulation are returned
  as attributes of this point pattern (see
  \code{\link[spatstat.random]{rNeymanScott}}). Furthermore, the simulated intensity
  function is returned as an attribute \code{"Lambda"}, if
  \code{saveLambda=TRUE}.
}
\details{
  This algorithm generates a realisation of the Neyman-Scott process
  with Cauchy cluster kernel, inside the window \code{win}.

  The process is constructed by first
  generating a Poisson point process of ``parent'' points 
  with intensity \code{kappa}. Then each parent point is
  replaced by a random cluster of points, the number of points in each
  cluster being random with a Poisson (\code{mu}) distribution,
  and the points being placed independently and uniformly
  according to a Cauchy kernel.

  In this implementation, parent points are not restricted to lie in the
  window; the parent process is effectively the uniform Poisson process
  on the infinite plane.

  This model can be fitted to data by the method of minimum contrast,
  maximum composite likelihood or Palm likelihood using
  \code{\link[spatstat.core]{kppm}}.
  
  The algorithm can also generate spatially inhomogeneous versions of
  the cluster process:
  \itemize{
    \item The parent points can be spatially inhomogeneous.
    If the argument \code{kappa} is a \code{function(x,y)}
    or a pixel image (object of class \code{"im"}), then it is taken
    as specifying the intensity function of an inhomogeneous Poisson
    process that generates the parent points.
    \item The offspring points can be inhomogeneous. If the
    argument \code{mu} is a \code{function(x,y)}
    or a pixel image (object of class \code{"im"}), then it is
    interpreted as the reference density for offspring points,
    in the sense of Waagepetersen (2006).
  }
  When the parents are homogeneous (\code{kappa} is a single number)
  and the offspring are inhomogeneous (\code{mu} is a
  function or pixel image), the model can be fitted to data
  using \code{\link[spatstat.core]{kppm}}. 

  If the pair correlation function of the model is very close
  to that of a Poisson process, deviating by less than
  \code{poisthresh}, then the model is approximately a Poisson process,
  and will be simulated as a Poisson process with intensity
  \code{kappa * mu}, using \code{\link[spatstat.random]{rpoispp}}.
  This avoids computations that would otherwise require huge amounts
  of memory.
}
\seealso{
  \code{\link[spatstat.random]{rpoispp}},
  \code{\link[spatstat.random]{rMatClust}},
  \code{\link[spatstat.random]{rThomas}},
  \code{\link[spatstat.random]{rVarGamma}},
  \code{\link[spatstat.random]{rNeymanScott}},
  \code{\link[spatstat.random]{rGaussPoisson}}.

  For fitting the model, see
  \code{\link[spatstat.core]{kppm}},
  \code{\link[spatstat.core]{clusterfit}}.
}
\examples{
 # homogeneous
 X <- rCauchy(30, 0.01, 5)
 # inhomogeneous
 ff <- function(x,y){ exp(2 - 3 * abs(x)) }
 Z <- as.im(ff, W= owin())
 Y <- rCauchy(50, 0.01, Z)
 YY <- rCauchy(ff, 0.01, 5)
}
\references{
  Ghorbani, M. (2013) Cauchy cluster process.
  \emph{Metrika} \bold{76}, 697-706.

  Jalilian, A., Guan, Y. and Waagepetersen, R. (2013)
  Decomposition of variance for spatial Cox processes.
  \emph{Scandinavian Journal of Statistics} \bold{40}, 119-137.

  Waagepetersen, R. (2007)
  An estimating function approach to inference for
  inhomogeneous Neyman-Scott processes.
  \emph{Biometrics} \bold{63}, 252--258.
}
\author{Abdollah Jalilian and Rasmus Waagepetersen.
  Adapted for \pkg{spatstat} by \adrian
  
  
}
\keyword{spatial}
\keyword{datagen}
