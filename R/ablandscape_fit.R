
#' Fitting with antibody landscapes
#' 
#' Fit an antibody landscape to titers and antigen positions.
#'
#' @param titers A vector of titers against each antigen.
#' @param coords A matrix of the antigen coordinates of each antigen.
#' @param bandwidth The bandwidth of the local regression.
#' @param degree The degree of the polynomials to be used, normally 1 or 2.
#' @param control Control parameters: see (\code{\link{ablandscape.control}})
#'
#' @return
#' @export
#'
ablandscape.fit <- function(
  titers,
  coords,
  bandwidth,
  degree,
  error.sd,
  control = list(),
  acmap = NULL
  ){
  
  # Keep a record
  fit <- list()
  class(fit) <- c("ablandscape.fit", "list")
  
  # Get names from titers
  if(is.null(dim(titers))) titer_names <- names(titers)
  else                     titer_names <- colnames(titers)
  
  # Work out coordinates from map if supplied
  if(!is.null(acmap)){
    
    # Match up map indices
    fit$acmap <- acmap
    fit$acmap_indices <- match(titer_names, agNames(acmap))
    if(sum(is.na(fit$acmap_indices)) > 0){
      stop(
        sprintf(
          "The following antigens were not found in the map supplied:\n\n'%s'\n\n",
          paste(titer_names[!titer_names %in% agNames(acmap)], collapse = "'\n'")
        )
      )
    }
    
  }
  
  if(missing(coords)){
    if(!is.null(acmap)){
      coords <- agCoords(acmap)[fit$acmap_indices,,drop=FALSE]
    }
  }
  
  # Check input
  if(is.null(dim(titers))){
    if(length(titers) != nrow(coords)) stop("Number coordinates does not match number of titers")
  } else {
    if(ncol(titers) != nrow(coords)) stop("Number coordinates does not match number of titers")
  }
  
  # Keep a record of pars used
  fit$control   <- do.call(ablandscape.control, control)
  fit$coords    <- coords
  fit$bandwidth <- bandwidth
  fit$degree    <- degree
  fit$error.sd  <- error.sd
  
  # Get less than and greater than coordinates
  fit$lessthans <- substr(titers, 1, 1) == "<"
  fit$morethans <- substr(titers, 1, 1) == ">"
  
  # Keep titers
  fit$titers <- titers
  
  # Get log titers
  fit$logtiters <- titer_to_logtiter(titers)
  
  # Get titer limits
  titer_lims <- calc_titer_lims(
    titers  = titers,
    control = control
  )
  fit$logtiters.upper <- titer_lims$max_titers
  fit$logtiters.lower <- titer_lims$min_titers
  
  # Record fit
  fit$fitted.values <- predict(
    object = fit,
    coords = coords,
    crop2chull = FALSE
  )
  
  # Get residuals
  fit_residuals <- fit$logtiters - fit$fitted.values
  
  fit$residuals <- fit_residuals
  fit$residuals[fit$morethans | fit$lessthans] <- NA
  
  fit$residuals.lessthan <- fit_residuals
  fit$residuals.lessthan[!fit$lessthans] <- NA
  
  fit$residuals.morethan <- fit_residuals
  fit$residuals.morethan[!fit$morethans] <- NA
  
  # Return the fit object
  fit
  
}




#' Fitting an antibody delta landscape
#' 
#' Fit an antibody landscape that represents the difference in reactivity
#' between two serum samples on a log scale.
#'
#' @param titers1 A vector of titers against each antigen.
#' @param titers2 A vector of titers against each antigen.
#' @param coords A matrix of the antigen coordinates of each antigen.
#' @param bandwidth The bandwidth of the local regression.
#' @param degree The degree of the polynomials to be used, normally 1 or 2.
#' @param control Control parameters: see (\code{\link{ablandscape.control}})
#'
#' @return
#' @export
#'
ablandscape.delta.fit <- function(
  titers1,
  titers2,
  coords,
  bandwidth,
  degree,
  error.sd,
  control = list()
  ){
  
  # Keep a record
  fit <- list()
  class(fit) <- c("ablandscape.delta.fit", "ablandscape.fit", "list")
  
  # Keep a record of pars used
  fit$control   <- do.call(ablandscape.control, control)
  fit$coords    <- coords
  fit$bandwidth <- bandwidth
  fit$degree    <- degree
  fit$error.sd  <- error.sd
  
  # Get measurable titers
  measurable_titers <- substr(titers1, 1, 1) != "<" &
                       substr(titers2, 1, 1) != "<" &
                       substr(titers1, 1, 1) != ">" &
                       substr(titers2, 1, 1) != ">"
  
  # Get log titers
  fit$logtiters1 <- as.vector(titer_to_logtiter(titers1))
  fit$logtiters2 <- as.vector(titer_to_logtiter(titers2))
  fit$logtiters.delta <- fit$logtiters2 - fit$logtiters1
  
  # Keep titers
  fit$titers <- list(
    titers1 = titers1,
    titers2 = titers2
  )
  
  # Get titer limits
  titer_lims <- calc_titer_diffs(titers1 = titers1,
                                 titers2 = titers2,
                                 control = control)
  fit$logtiters.delta.upper <- titer_lims$max_diffs
  fit$logtiters.delta.lower <- titer_lims$min_diffs
  
  # Record fit
  fit$fitted.values <- predict(object = fit,
                               coords = coords,
                               crop2chull = FALSE)
  
  # Get residuals
  fit_residuals <- fit$logtiters.delta - fit$fitted.values
  
  fit$residuals <- fit_residuals
  fit$residuals[!measurable_titers] <- NA
  
  # Return the fit object
  fit
  
}



