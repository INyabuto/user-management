library(httr)
library(jsonlite)
library(readxl)
library(stringr)
library(knitr)
library(kableExtra)
suppressMessages(library(dplyr))

#'
#' a function to generate UIDs
#' @param codeSize = 11
#' @return 11 characters 

generateUID <- function(codeSize = 11){
  # Generate a random seed
  runif(1)
  allowedLetters <- c(LETTERS, letters)
  allowedChars <- c(LETTERS, letters, 0:9)
  # first character must be a letter according to the DHIS2 spec
  firstChar <- sample(allowedLetters, 1)
  otherChars <- sample(allowedChars, codeSize - 1)
  uid <- paste(c(firstChar, paste(otherChars, sep = "", collapse = "")), sep = "", collapse = "")
  return(uid)
}

#'
#'  A function to login 
#'  @param baseurl the main part of the url
#'  @param username username
#'  @param password password
#'  @return boolean TRUE if logged in successfully
loginDHIS2 <- function(baseurl, username, password){
  url <- paste0(baseurl, "api/me")
  r <- GET(url, authenticate(username, password))
  assertthat::assert_that(r$status_code == 200)
}

#'
#'A function to reference the parent object with an ID
#'

coordinate <- function(x, lat, long){
  x <- list(latitude = lat,
            longitude = long)
  return(x)
}

#'
#'GET all dataElements names and ids
#'@param baseurl server url
#'@return a dataframe with id and displayName
getDataElement <- function(baseurl){
  url <- paste0(baseurl,'api/dataElements')
  r <- httr::GET(url,config = list(ssl_verifyPeer = FALSE), timeout(60))
  assertthat::assert_that(r$status_code == 200)
  d <- jsonlite::fromJSON(content(r,"text"))$dataElements
  return(d)
}

#'
#'GET all organisationUnits at a specified level
#'@param baseurl server url
#'@param id UID of the parent orgUnit
#'@param level orgUnit level
getOrgUnit <- function(baseurl, id, level){
  url <- paste0(baseurl, "api/organisationUnits/", paste0(id,"?level=",level,"&fields=id,name"))
  r <- httr::GET(url, config = list(ssl_verifyPeer = FALSE), timeout(60))
  assertthat::assert_that(r$status_code == 200)
  d <- jsonlite::fromJSON(content(r,"text"))$organisationUnits
  return(d)
}

#'
#'POST dataValues
#'@param baseurl server url
#'@param df a dataframe object to be posted. 
postDataValues <- function(baseurl, df){
  d <- httr::POST(paste0(baseurl,"api/27/dataValueSets?preheatCache=true&skipExistingCheck=true&skipPatternValidation=true"),
                  body = toJSON(list(dataValues = df), auto_unbox = TRUE), content_type_json())
  assertthat::assert_that(d$status_code==200)
  return(content(d,"text"))
}

#'
#'run Analytics
#'@param baseurl 

runAnalytics <- function(baseurl){
  r <- httr::POST(paste0(baseurl,"api/resourceTables"))
}

#'
#'Vector to list
#'@param x a vector
#'@return a list of the specifed vector
parent <- function(x){
  y <- list(id = x)
  return(y)
}


#'
#'A funtion to split orgUnit by a pattern 
#'@param x a vector of organizationUnits
#'@param pattern a regrex expression
#'@param part an integer consisting either 1 or 2
#'@return a vector of split organizations

orgSplit <- function(x, pattern = '[(]', part=1){
  org <- stringr::str_split(x, pattern)
  org <- rapply(org, function(y) head(y,part))
  org <- stringr::str_trim(org,side = "both")
  return(tolower(org))
}

#'
#'A function to select the value of a partcular index in a vector
#'@param x a vector 
#'@param index 
Index <- function(x,index = 1){
  return(x[index])
}

#'
#'A function to popout ancestors, split them from an orgUnit
#'@param x a list of ancestor orgUnits
#'@param index an index of the orgUnit to pop up
#'@return a vector of split organizationUnits
#'
ancestorSplit <- function(x,index = 1, pattern = '[(]', part = 1){
  ancestor <- rapply(x, function(x) Index(x,index))
  ancestor <- orgSplit(ancestor, pattern, part)
  return(ancestor)
  
}


#'
#'Function to get a list of orgUnits
#'@param baseurl server url
#'@return a df with OrgUnits nameand Ids
ous_all <- function(baseurl, ou_id = ""){
  ous_r <- httr::GET(paste0(baseurl,"api/29/organisationUnits/",ou_id,"?fields=id,name&includeDescendants=true"))
  ous_d <- jsonlite::fromJSON(content(ous_r,"text"))$organisationUnits
  return(ous_d)
}


#' Translate event dataElements UIDs to names
#' @param x a df with dataElements uuids
#' @param cei_des a df with program dataElements
#' @return a translated df with only dataElement  and Values
dv_wide <- function(x,cei_des){
  #x <- x %>% dplyr::select(c("dataElement","value"))
  x$dataElement <- plyr::mapvalues(x$dataElement, from = cei_des$dataElement$id, to = cei_des$dataElement$name, warn_missing = F)
  # reshape to wide 
  x <- tidyr::spread(x,dataElement,value,fill = "") 
  x <- tibble::as_tibble(lapply(x,paste0,collapse=""))
  x <- x %>% dplyr::select(-c(lastUpdated,storedBy,created,providedElsewhere))
  return(x)
}



#'remap DHIS2 metadata objects
#'@param items a list of metadata objects
#'@param id a string or ID of an object to find
#'@return name of the object
remapValues <- function(items, id){
  x <- items[names(items) == id]
  x <- x[[1]]$name
  return(x)
}


#' Resave objects stored in .RData file
resave <- function(..., list = character(), file) {
  previous  <- load(file)
  var.names <- c(list, as.character(substitute(list(...)))[-1L])
  for (var in var.names) assign(var, get(var, envir = parent.frame()))
  save(list = unique(c(previous, var.names)), file = file)
}


#' Remove nulls form a list
compact <- function(x){
  x[!vapply(x, is.null, logical(1))]
}
