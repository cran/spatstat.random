\name{clusterkernel}
\alias{clusterkernel}
\alias{clusterkernel.character}
\title{
  Extract Cluster Offspring Kernel
}
\description{
  Given a cluster point process model, this command
  returns the probability density of the cluster offspring.
}
\usage{
clusterkernel(model, \dots)
\method{clusterkernel}{character}(model, \dots)
}
\arguments{
  \item{model}{
    Cluster model. Either a fitted cluster or Cox model
    (object of class \code{"kppm"}), or a character string
    specifying the type of cluster model.
  }
  \item{\dots}{
    Parameter values for the model,
    when \code{model} is a character string.
  }
}
\details{
  Given a specification of a cluster point process model, this command
  returns a \code{function(x,y)} giving the two-dimensional
  probability density of the cluster offspring points assuming a cluster parent
  located at the origin.

  The function \code{clusterkernel} is generic,
  with methods for class \code{"character"} (described here)
  and \code{"kppm"} (described in \code{\link[spatstat.model]{clusterkernel.kppm}}).
}
\value{
  A function in the \R language with arguments \code{x,y,\dots}.
}
\author{
  \spatstatAuthors.
}
\seealso{
  \code{\link[spatstat.model]{clusterkernel.kppm}}),
  \code{\link{clusterfield}}, \code{\link[spatstat.model]{kppm}}.
}
\examples{
  f <- clusterkernel("Thomas", kappa=10, scale=0.5)
  f(0.1, 0.2)
}
\keyword{spatial}
