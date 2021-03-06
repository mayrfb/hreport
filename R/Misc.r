utils::globalVariables(c('Freq', '.group.'))

#' Set hreport Options
#'
#' @param study an optional study mnemonic (character string) needed when multiple studies are being analyzed (or when one study is divided into distinct strata)
#' @param \dots a series of options for which non-default values are desired:
#' \itemize{
#'  \item{\code{tx.pch}:}{symbols corresponding to treatments}
#'  \item{\code{tx.col}:}{colors corresponding to treatments}
#'  \item{\code{tx.linecol}:}{colors for lines in line plots}
#'  \item{\code{nontx.col}:}{colors for categories other than treatments}
#'  \item{\code{tx.lty}:}{line types corresponding to treatments}
#'  \item{\code{tx.lwd}:}{line widths corresponding to treatments}
#'  \item{\code{tx.var}:}{character string name of treatment variable}
#'  \item{\code{er.col}:}{2-vector with names \code{"enrolled","randomized"} containing colors to use for enrolled and randomized in needle displays}
#'  \item{\code{alpha.f}:}{single numeric specifying alpha adjustment to be applied to all colors.  Default is 1 (no adjustment)}
#'  \item{\code{denom}:}{named vector with overall sample sizes}
#' }
# See https://github.com/plotly/plotly.py/blob/master/plotly/colors.py#L83-L87
sethreportOption <- function(..., study=' ') {
  hop     <- getOption('hreport')
  default <- if(length(hop)) hop[[study]]
  opts    <- list(...)
  alpha.f <- if(length(opts$alpha.f)) opts$alpha.f else 1
  ## Used to use tx.col = adjustcolor(c('black', '#0080ff'), alpha.f=alpha.f)
  royalblue  <- '#4169E1'
  darkorange <- '#FF8C00'
  if(! length(default))
    default <-
      list(tx.pch = 16:17,
           tx.col     = c(royalblue, darkorange),
           tx.linecol = c(royalblue, darkorange),
           nontx.col = adjustcolor(c("#1b9e77", "#d95f02", "#7570b3", "#e7298a",
             "#66a61e", "#e6ab02", "#a6761d", "#666666"),
             alpha.f=alpha.f),  ## see colorbrewer2.org
           tx.lty = c(1, 1), tx.lwd = c(1, 2),
           tx.var = '', er.col = NULL, alpha.f = 1,
           denom = c(enrolled=NA, randomized=NA))
  
  if(length(opts)) {
    if(any(names(opts) %nin% names(default)))
      stop(paste('hreport options must be one of the following:',
                 paste(names(default), collapse=' ')))
    default[names(opts)] <- opts
  }
  i <- names(opts$denom) %nin% c('enrolled', 'randomized')
  if(any(i) && sum(opts$denom[i]) != opts$denom['randomized'])
    stop('sum of # subjects randomized to each treatment must = total number randomized')
  if(! length(default$er.col))
    default$er.col <-
      adjustcolor(setdiff(c('red', 'green', "#0080ff", "#ff00ff",
                            "darkgreen", "#ff0000", "orange", "#00ff00",
                            "brown"),
                          default$tx.col)[1 : 2], alpha.f=alpha.f)
  hop[[study]] <- default
  options(hreport = hop)
  invisible()
}

#'  
#' Get hreport Options
#'
#' Get hreport options, assigning default values of unspecified options.
#'
#' @param opts character vector containing list of option names to retrieve.  If only one element, the result is a scalar, otherwise a list.  If \code{opts} is not specified, a list with all current option settings is returned.
#' @param study character string specifying an optional study designation
#' @export

gethreportOption <- function(opts=NULL, study=' ') {
  hop <- getOption('hreport')
  if(! length(hop)) return(hop)
  hop <- hop[[study]]
  if(! length(hop)) return(hop)
  hop <- if(length(opts)) hop[opts] else hop
  if(length(opts) == 1) hop <- hop[[1]]
  hop
}

#' Compute Sample Fractions
#'
#' Uses denominators stored with \code{sethreportOption} along with counts specified to \code{SampleFrac} to compute fractions of subjects in current analysis
#'
#' @param n integer vector, named with \code{"enrolled","randomized"} and optionally also including treatment levels.
#' @param nobsY a result of the the \code{nobsY} Hmisc function
#' @param table set to \code{TRUE} to return as an attribute \code{"table"} a character string containing an HTML table showing the pertinent frequencies created from \code{n} and the \code{denom} option, and if \code{nobsY} is present, adding another table with response variable-specific counts.
#' @param study character string with study ID
#' @export

sampleFrac <- function(n, nobsY=NULL, table=TRUE, study=' ') {
  denom <- gethreportOption('denom', study=study)
  if(any(is.na(denom))) stop('denom must be defined with sethreportOption()')
  if(names(n)[1] != 'enrolled')
    n <- structure(c(n[1], n), names=c('enrolled', names(n)))
  if(all(names(n) %in% c('enrolled', 'randomized')))
    denom <- denom[unique(c('enrolled', names(n)))]
  if(length(n) != length(denom))
    stop('length of n does not equal length of denom')
  if(any(names(n) != names(denom)))
    stop('n does not have same names as denom in the same order')
  f <- n / denom
  if(any(f > 1.)) warning('A sample fraction > 1.0; assuming analysis is to compare randomized and non-randomized subjects\nfraction capped at 1.0')
  f <- pmin(f, 1.)
  if(! table) return(f)
  tab <- data.frame(upFirst(names(n)), denom, n)
  size <- 54; border <- 1
  tab <- html(tab, align=c('l', 'r', 'r'),
              header=c('Category', 'N', 'Used'),
              file=FALSE, size=size, border=border, rownames=FALSE)
  tab <- unclass(tab)
  if(length(nobsY)) {
    if(length(m <- nobsY$nobsg)) {
      m <- t(m)
      d <- cbind(Variable=rownames(m), as.data.frame(m))
      tab2 <- html(d, align=c('l', rep('r', ncol(m))),
                   file=FALSE, size=size, border=border, rownames=FALSE)
    }
    else {
      m <- nobsY$nobs
      d <- data.frame(Variable=names(m), N=m)
      tab2 <- html(d, align=c('l', 'r'),
                   header=c('Variable', 'N'),
                   file=FALSE, size=size, border=border, rownames=FALSE)
    }
    tab <- c(tab, unclass(tab2))
  }
  attr(f, 'table') <- tab
  f
}

#' Draw Needles
#'
#' Create an html base64 string from a png graphic to draw needles for current sample sizes.  Uses colors set by call to \code{sethreportOptions}.
#'
#' @param sf output of \code{sampleFrac}
#' @param study character string specifying study ID
#' @export

dNeedle <- function(sf, study=' ') {
  co <- gethreportOption(c('er.col', 'tx.col'), study=study)
  co <- c(co$er.col, co$tx.col)
  
  tobase64image(pngNeedle(sf, col=co))
}



#' Compute mfrow Parameter
#'
#' Compute a good \code{par("mfrow")} given the
#' number of figures to plot.
#'
#' @param n numeric. Total number of figures to place in layout.
#' @param small logical. Set to \sQuote{TRUE} if the plot area should be
#' smaller to accomodate many plots.
#' @return return numeric vector.
#' oldmfrow <- mfrowSet(8)
mfrowSuggest <- function(n, small=FALSE) {
  omf <- mf <- par('mfrow')
  if(length(mf) == 0) mf <- c(1,1)
  if(n == 1) return(mf)
  if(n > 1 & max(mf) == 1) {
    if(small) {
      mf <- if(n <= 2) {
        c(1, 2)
      } else if(n <= 4) {
        c(2,2)
      } else if(n <= 6) {
        c(2,3)
      } else if(n <= 12) {
        c(3,4)
      } else if(n <= 16) {
        c(4,4)
      } else if(n <= 20) {
        c(4,5)
      } else if(n <= 24) {
        c(4,6)
      } else if(n <= 25) {
        c(5,5)
      } else if(n <= 30) {
        c(5,6)
      } else if(n <= 36) {
        c(6,6)
      } else if(n <= 42) {
        c(6,7)
      } else {
        c(6,8)
      }
    } else {
      mf <- if(n <= 2) {
        c(1,2)
      } else if(n <= 4) {
        c(2,2)
      } else if(n <= 6) {
        c(2,3)
      } else if(n <= 9) {
        c(3,3)
      } else {
        c(4,3)
      }

      if(n > 12 & n <= 16) {
        mf <- c(4,4)
      }
    }
    }
  mf
}
