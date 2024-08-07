\name{expand.owin}
\alias{expand.owin}
\title{Apply Expansion Rule}
\description{
  Applies an expansion rule to a window.
}
\usage{
 expand.owin(W, \dots)
}
\arguments{
  \item{W}{A window.}
  \item{\dots}{
    Arguments passed to \code{\link{rmhexpand}} to
    determine an expansion rule.
  }
}
\value{
  A window (object of class \code{"owin"}).
}
\details{
  The argument \code{W} should be a window (an object of class
  \code{"owin"}).

  This command applies the expansion rule specified by the
  arguments \code{\dots} to the window \code{W}, yielding another
  window.

  The arguments \code{\dots} are passed to \code{\link{rmhexpand}}
  to determine the expansion rule.

  For other transformations of the scale, location and orientation
  of a window, see \code{\link[spatstat.geom]{shift}}, \code{\link[spatstat.geom]{affine}}
  and \code{\link[spatstat.geom]{rotate}}.
}
\seealso{
  \code{\link{rmhexpand}} about expansion rules.
  
  \code{\link[spatstat.geom]{shift}},
  \code{\link[spatstat.geom]{rotate}},
  \code{\link[spatstat.geom]{affine}} for other types of manipulation.
}
\examples{
   expand.owin(square(1), 9)
   expand.owin(square(1), distance=0.5)
   expand.owin(letterR, length=2)
   expand.owin(letterR, distance=0.1)
}
\author{\adrian
  
  
  and \rolf
  
}
\keyword{spatial}
\keyword{manip}
