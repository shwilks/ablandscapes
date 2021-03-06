
#' Fit landscape to a set of coordinates
#' 
fit_lndscp2coords <- function(coords,
                              ag_coords,
                              titers,
                              max_titers,
                              min_titers,
                              bandwidth,
                              degree,
                              error.sd,
                              crop2chull = TRUE,
                              control    = list()){
  
  apply(X          = coords,
        MARGIN     = 1,
        FUN        = fit_lndscp2point,
        ag_coords  = ag_coords,
        titers     = titers,
        max_titers = max_titers,
        min_titers = min_titers,
        bandwidth  = bandwidth,
        degree     = degree,
        error.sd   = error.sd,
        crop2chull = crop2chull,
        control    = control)
  
}


#' Fit landscape to single coordinate point
#'
fit_lndscp2point <- function(point_coords,
                             ag_coords,
                             titers,
                             max_titers,
                             min_titers,
                             bandwidth,
                             degree,
                             error.sd,
                             crop2chull = TRUE,
                             control    = list()) {
  
  # Get model variables to send to optimiser
  pars <- do.call(ablandscape.control, control)
  
  # Return NA if outside convex hull
  if(crop2chull) {
    withinChull <- lndscp_checkChull(point_coords, ag_coords)
    if(!withinChull) {
      return(
        list(par   = c(NA, NA, NA),
             negll = NA)
      )
    }
  }
  
  if (is.null(pars$model.fn)) {
    # Run with the default model function
    result <- model_lndscp_height(
      point_coords = point_coords,
      ag_coords    = ag_coords,
      titers       = titers,
      max_titers   = max_titers,
      min_titers   = min_titers,
      bandwidth    = bandwidth,
      degree       = degree,
      error.sd     = error.sd,
      pars         = pars
    )
    return(result)
  } else {
    # Fit with user-specified function
    return(
      pars$model.fn(
        point_coords = point_coords,
        ag_coords    = ag_coords,
        titers       = titers,
        max_titers   = max_titers,
        min_titers   = min_titers,
        bandwidth    = bandwidth,
        degree       = degree,
        error.sd     = error.sd,
        pars         = pars
      )
    )
  }
  
  
}


#' Function to model the landscape height
#' 
model_lndscp_height <- function(point_coords,
                                ag_coords,
                                titers,
                                max_titers,
                                min_titers,
                                bandwidth,
                                degree,
                                error.sd,
                                pars){
  
  # Make ag coords relative to the point coord
  ag_coords <- ag_coords - matrix(point_coords, 
                                  nrow = nrow(ag_coords), 
                                  ncol = ncol(ag_coords),
                                  byrow = TRUE)
  
  # Make coords polynomial
  ag_coords_poly <- polycoords(ag_coords, degree)
  
  # Perform the fit
  result <- nlminb(
    start       = c(0, rep(0, ncol(ag_coords_poly))),
    objective   = negll_titer_lm,
    upper       = c(pars$max.titer.possible, rep(pars$max.slope, ncol(ag_coords))),
    lower       = c(pars$min.titer.possible, rep(-pars$max.slope, ncol(ag_coords))),
    ag_coords   = ag_coords_poly,
    ag_weights  = tricubic.weights(ag_coords, bandwidth),
    max_titers  = matrix(max_titers, nrow = 1),
    min_titers  = matrix(min_titers, nrow = 1),
    error_sd    = error.sd
  )
  
  # Return the best height fit
  list(par   = result$par,
       negll = result$objective)
  
}


#' Check if coordinates are within convex hull of ag coordinates
#'
lndscp_checkChull <- function(point_coords,
                              ag_coords) {
  
  # Return FALSE if outside convex hull
  if(ncol(ag_coords) == 1) {
    if(point_coords < min(ag_coords) | point_coords > max(ag_coords)) {
      return(FALSE)
    }
  }
  if(ncol(ag_coords) == 2) {
    if(1 %in% chull(rbind(point_coords,ag_coords))) {
      return(FALSE)
    }
  }
  if(ncol(ag_coords) > 2) {
    if(1 %in% geometry::convhulln(p = rbind(point_coords, ag_coords))){
      return(FALSE)
    }
  }
  
  # Return TRUE otherwise
  return(TRUE)
  
}


# Get coordinates for polynomial fitting
polycoords <- function(coords, degree){
  
  # Then assign coordinates based on degree of fit specified
  coords_poly <- c()
  for(dg in seq_len(degree)) {
    for(x in seq_len(ncol(coords))) {
      coords_poly <- cbind(coords_poly, coords[,x]^dg)
    }
  }
  coords_poly
  
}

#' Calculate the antigen weights
#' 
#' @export
tricubic.weights <- function(coords, bandwidth){
  
  d <- sqrt(rowSums(coords^2))
  D <- bandwidth
  
  (1 - (d/D)^3)^3
  
}



