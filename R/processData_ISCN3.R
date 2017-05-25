#' Primary function to load all of ISCN3 data
#'
#' @param dir string identifying the folder the data is in. Should have a subfolder 'Layers' containing all ISCN_ALL_DATA_LAYER_C*_1-1.csv files.
#'
#' @return a data frame with all data in the correct format

#' @export
processData_ISCN3 <- function(dir='repoData/ISCN_3'){

  data1.ls <- processWorksheet(csvFile=
                                 sprintf('%s/Layers/ISCN_ALL_DATA_LAYER_C1_1-1.csv', dir),
                               verbose=TRUE)

  data2.ls <- processWorksheet(csvFile=
                                 sprintf('%s/Layers/ISCN_ALL_DATA_LAYER_C2_1-1.csv', dir),
                               verbose=TRUE)

  data3.ls <- processWorksheet(csvFile=
                                 sprintf('%s/Layers/ISCN_ALL_DATA_LAYER_C3_1-1.csv', dir),
                               verbose=TRUE)

  data4.ls <- processWorksheet(csvFile=
                                 sprintf('%s/Layers/ISCN_ALL_DATA_LAYER_C4_1-1.csv', dir),
                               verbose=TRUE)
  #merge easy========
  study.df <- data1.ls$study
  fieldTreatment.df <- data1.ls$fieldTreatment
  labTreatment.df <- data1.ls$labTreatment

  lab.df <- unique(rbind.fill(rbind.fill(rbind.fill(data1.ls$lab,data2.ls$lab),
                                         data3.ls$lab), data4.ls$lab))

  field.df <- unique(rbind.fill(rbind.fill(rbind.fill(data1.ls$field,data2.ls$field),
                                           data3.ls$field), data4.ls$field))
  field.df$value <- as.factor(field.df$value)
  field.df$layer_units <- as.factor(field.df$layer_units)


  fieldNotes.df <- field.df[,c('fieldID', 'measurement', 'value')]
  field.df <- unique(field.df[,c('fieldID', 'lat', 'long', 'observation_date',
                                 'layer_top', 'layer_bot', 'layer_units')])
  #mergeMeasures====
  measureTemp.df <-
    merge(merge(data1.ls$measurement, data2.ls$measurement, by=c('type', 'method'),
                suffixes=c('.data1', '.data2'), all=TRUE),
          merge(data3.ls$measurement, data4.ls$measurement, by=c('type', 'method'),
                suffixes=c('.data3', '.data4'), all=TRUE), all=TRUE)

  measureTemp.df <- ddply(measureTemp.df, c('type'), function(xx){
    xx$measurementID <- sprintf('%s_%02d', xx$type, 1:nrow(xx))
    return(xx)
  })
  measurement.df <- measureTemp.df[,c('type', 'method', 'measurementID')]

  #Construct samples========
  sample.df <- ddply(data1.ls$samples, 'measurementID', function(xx){
    #cat('replacing [', xx$measurementID[1])
    xx$measurementID <- subset(measureTemp.df,
                               xx$measurementID[1] == measurementID.data1)$measurementID
    #cat('] with [',xx$measurementID[1],']\n')
    return(xx)
  })

  sample.df <- rbind.fill(sample.df,
                          ddply(data2.ls$samples, 'measurementID', function(xx){
                            #cat('replacing [', xx$measurementID[1])
                            xx$measurementID <- subset(measureTemp.df,
                                                       xx$measurementID[1] ==
                                                         measurementID.data2)$measurementID
                            #cat('] with [',xx$measurementID[1],']\n')
                            return(xx)
                          }))

  sample.df <- rbind.fill(sample.df,
                          ddply(data3.ls$samples, 'measurementID', function(xx){
                            #cat('replacing [', xx$measurementID[1])
                            xx$measurementID <- subset(measureTemp.df,
                                                       xx$measurementID[1] ==
                                                         measurementID.data3)$measurementID
                            #cat('] with [',xx$measurementID[1],']\n')
                            return(xx)
                          }))

  sample.df <- rbind.fill(sample.df,
                          ddply(data4.ls$samples, 'measurementID', function(xx){
                            #cat('replacing [', xx$measurementID[1])
                            xx$measurementID <- subset(measureTemp.df,
                                                       xx$measurementID[1] == measurementID.data4)$measurementID
                            #cat('] with [',xx$measurementID[1],']\n')
                            return(xx)
                          }))
  sample.df$fieldID <- as.factor(sample.df$fieldID)
  sample.df$measurementID <- as.factor(sample.df$measurementID)
  sample.df$unit <- as.factor(sample.df$unit)

  return(list(study=study.df, labTreatment=labTreatment.df, fieldTreatment=fieldTreatment.df,
              field=field.df, fieldNotes=fieldNotes.df, measurement=measurement.df,
              sample=sample.df))
}

#' Process each ISCN worksheet
#'
#' @param csvFile string identifying the CSV file
#' @param verbose boolean if you want LOTS of messages
#'
#' @return a list of data frames
processWorksheet <- function(csvFile='Layers/ISCN_ALL_DATA_LAYER_C1_1-1.csv',
                             verbose=TRUE){
  ##Out of memory erros
  #header <- read.xlsx('Layers/ISCN_ALL_DATA_LAYER_C1_1-1.xlsx', sheetIndex=1, startRow=1, endRow=2)
  #data.df <- read.xlsx2('Layers/ISCN_ALL_DATA_LAYER_C1_1-1.xlsx', sheetIndex=1)

  #Load file========
  if(verbose) cat('loading csv:', csvFile, '\n')
  data.df <- read.csv(csvFile, stringsAsFactors=FALSE)
  if(verbose) cat('inital size: ', format(object.size(data.df), units='Mb'), '\n')

  #trim replicates
  #data.df <- subset(data.df, !grepl('ISCN SOC stock', dataset_name_soc))
  #if(verbose) cat('trim ISCN SOC stocks: ', format(object.size(data.df), units='Mb'), '\n')

  data.df <- unique(data.df)
  if(verbose) cat('trim non-unique: ', format(object.size(data.df), units='Mb'), '\n')

  #Process header column =============
  ##process the header for units
  if(verbose) cat('setting up header\n')
  header <- read.csv(csvFile, nrows=1, header=FALSE)

  header.df <- data.frame(header=unlist(header),
                          measurement=gsub(' \\(.*\\)', '', unlist(header)),
                          unit=gsub('\\)', '', gsub('.* \\(', '', unlist(header))),
                          stringsAsFactors=FALSE)
  header.df$unit[header.df$measurement == header.df$unit] <- NA
  header.df$unit[grepl('ph_(cacl|h2o|other)', header.df$measurement)] <- 'unitless'
  header.df$unit[grepl('root_quant_size', header.df$measurement)] <- 'unitless'
  header.df$unit[92:95] <- 'unitless'

  #Set up study, lab, and treatment ===========
  ##Set up the easy data frame
  if(verbose) cat('reading study/lab/treatment information\n')
  study.df <- data.frame(studyID = header[1], doi='10.17040/ISCN/1305039', permissions='acknowledgement')

  lab.df <- data.frame(labID=unique(data.df[,2])) #ignore dataset_name_SOC, back out SOC later

  fieldTreatment.df <- data.frame(fieldTreatmentID=NA) #no field treatment
  labTreatment.df <- data.frame(labTreatmentID=NA) #no lab treatment

  #set up field IDs============
  if(verbose) cat('setting up field ID\n')
  field.df <- unique(data.df[,c(4:22, c(84, 94, 95))])
  names(field.df) <- as.character(header.df$measurement[c(4:22, c(84, 94, 95))])
  field.df$fieldID <- field.df$layer_name
  field.df <- melt(field.df, id.vars=c('fieldID', 'lat', 'long', 'observation_date',
                                       'layer_top', 'layer_bot'),
                   variable.name='measurement', factorsAsStrings=TRUE)
  field.df$layer_units <- 'cm'
  field.df$layer_top <- as.numeric(as.character(field.df$layer_top))
  field.df <- field.df[!grepl('^\\s*$',field.df$value),]

  ####Pull data subsets, sampleID = fieldID = layer_name [12]
  if(verbose) cat('pulling data\n')
  #BulkDensity===================
  if(verbose) cat('Bulk density \n')
  ##Bulk density columns 23:28
  #header.df[c(12, 23:28),]
  sampleTemp <- data.df[, c(12, 23:28)]
  names(sampleTemp) <- header.df$measurement[c(12,23:28)]
  names(sampleTemp)[1] <- 'fieldID'

  temp <- processMethodBlock(methodNames=header.df$measurement[c(23, 28)],
                             sampleTemp=sampleTemp,
                             unit.df=header.df[c(24:27), c('measurement', 'unit')],
                             verbose=FALSE)

  #merge results
  measurement.df <- temp$measurement
  sample.df <- temp$sample

  #CARBON=====================
  if(verbose) cat('Carbon \n')
  ##Carbon, columns 29-33
  #header.df[c(12, 29:33),]
  sampleTemp <- data.df[, c(12, 29:33)]
  names(sampleTemp) <- header.df$measurement[c(12,29:33)]
  names(sampleTemp)[1] <- 'fieldID'
  headerTemp <-

    temp <- processMethodBlock(methodNames=header.df$measurement[29:30],
                               sampleTemp=sampleTemp,
                               unit.df=header.df[c(31:33), c('measurement', 'unit')])
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  #Nitrogen=============================
  if(verbose) cat('Nitrogen \n')
  ##Nitrogen, columns 34-35
  #header.df[c(12, 34:35),]
  sampleTemp <- data.df[, c(12, 34:35)]
  names(sampleTemp) <- header.df$measurement[c(12,34:35)]
  names(sampleTemp)[1] <- 'fieldID'
  temp <- processMethodBlock(methodNames=NULL,
                             sampleTemp=sampleTemp,
                             unit.df=header.df[c(34:35), c('measurement', 'unit')])
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  #SOC==================
  if(verbose) cat('SOC\n')
  ##SOC, columns 36-38
  #header.df[c(12, 36:38),]
  sampleTemp <- data.df[, c(12, 36:38)]
  names(sampleTemp) <- header.df$measurement[c(12,36:38)]
  names(sampleTemp)[1] <- 'fieldID'
  temp <- processMethodBlock(methodNames=header.df$measurement[c(37:38)],
                             sampleTemp=sampleTemp,
                             unit.df=header.df[c(36), c('measurement', 'unit')])
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  ##pH, columns 39-42
  if(verbose) cat('pH\n')
  #header.df[c(12, 39:42),]
  sampleTemp <- data.df[, c(12, 39:42)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(39:42)])
  temp <- processMethodBlock(methodNames=header.df$measurement[c(39)],
                             sampleTemp=sampleTemp,
                             unit.df=header.df[c(40:42), c('measurement', 'unit')])
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  ##CaCO3 + Texture + CAT exchange, column 43:46, 49
  if(verbose) cat('CaCO3, texture, cat exchange \n')
  #header.df[c(12, 43:46, 49),]
  sampleTemp <- data.df[, c(12, 43:46, 49)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(43:46, 49)])
  temp <- processMethodBlock(methodNames=NULL,
                             sampleTemp=sampleTemp,
                             unit.df=header.df[c(43:46, 49), c('measurement', 'unit')])
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  ##WPG2, columns 47 48
  if(verbose) cat('wpg2\n')
  #header.df[c(12, 47, 48),]
  sampleTemp <- data.df[, c(12, 47, 48)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(47:48)])
  temp <- processMethodBlock(methodNames=header.df$measurement[47],
                             sampleTemp=sampleTemp,
                             unit.df=header.df[c(47:48), c('measurement', 'unit')])
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  ##Al, columns 50, 52, 59, 60
  ##Fe, columns 53, 55, 59, 60
  ##Mn, columns 56, 58, 59 ??60
  #header.df[c(12, 50:60),]
  if(verbose) cat('Al Fe Mn\n')
  sampleTemp <- data.df[, c(12, 50:60)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(50:60)])
  temp <- processMethodBlock(methodNames=header.df$measurement[60],
                             unitName=header.df$measurement[59],
                             sampleTemp=sampleTemp)
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  #BC===============
  if(verbose) cat('Bc\n')
  ##BC, columns 61:67
  #header.df[c(12, 61:67),]
  sampleTemp <- data.df[, c(12, 61:67)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(61:67)])
  temp <- processMethodBlock(methodNames=header.df$measurement[67],
                             unitName=header.df$measurement[66],
                             sampleTemp=sampleTemp)
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  #CEC===========
  if(verbose) cat('CEC\n')
  ##CEC_h, columns 68:71
  #header.df[c(12, 68:71),]
  sampleTemp <- data.df[, c(12, 68:71)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(68:71)])
  temp <- processMethodBlock(methodNames=NULL,
                             unitName=header.df$measurement[71],
                             sampleTemp=sampleTemp)
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)
  #BS=======
  if(verbose) cat('BS\n')
  ##bs, columns 72:73
  sampleTemp <- data.df[, c(12, 72:73)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(72:73)])
  temp <- processMethodBlock(methodNames=NULL,
                             unitName=NULL,
                             unit.df=header.df[c(72:73), c('measurement', 'unit')],
                             sampleTemp=sampleTemp)
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  #Metal==========
  if(verbose) cat('metals \n')
  ##metal_ext, columns 74:77
  sampleTemp <- data.df[, c(12, 74:77)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(74:77)])
  temp <- processMethodBlock(methodNames=header.df$measurement[77],
                             unitName=header.df$measurement[76],
                             unit.df=NULL,
                             sampleTemp=sampleTemp)
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  #P ============
  if(verbose) cat('P\n')
  ##P, columns 78:83
  sampleTemp <- data.df[, c(12, 78:83)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(78:83)])
  temp <- processMethodBlock(methodNames=header.df$measurement[83],
                             unitName=header.df$measurement[82],
                             unit.df=NULL,
                             sampleTemp=sampleTemp)
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  #Roots + Isotope + texture + locator
  ##Root, column 84:85 84is TEXT move to field description
  ##Isotope, 86:93
  ##textureClass, 94 TEXT move to field description
  ##locator, 95 TEXT move to field description
  if(verbose) cat('roots isotope texture locator\n')
  sampleTemp <- data.df[, c(12, 85:93)]
  names(sampleTemp) <- c('fieldID', header.df$measurement[c(85:93)])
  temp <- processMethodBlock(methodNames=NULL,
                             unitName=NULL,
                             unit.df=header.df[c(85:93),],
                             sampleTemp=sampleTemp)
  #merge results
  measurement.df <- rbind.fill(measurement.df, temp$measurement)
  sample.df <- rbind.fill(sample.df, temp$sample)

  if(verbose) cat('done with processWorksheet\n')
  return(list(study=study.df, field=field.df, lab=lab.df,
              fieldTreatment=fieldTreatment.df, labTreatment=labTreatment.df,
              measurement=measurement.df, samples=sample.df))
}

#' Process a methods block
#'
#' Force the samples to discard repeats
#'
#' @param methodNames strings identifying the metods name for the block
#' @param unitName strings identifying the unit name for the block
#' @param sampleTemp stirngs identifying the samples for the block
#' @param unit.df data frame for the unit for the block keyed on the measure
#' @param verbose boolean if you want lots of error messages
#'
#' @return a list of data frames with the sample data and measurement information
processMethodBlock <- function(methodNames=NULL, unitName=NULL,
                               sampleTemp, unit.df=NULL, verbose=FALSE){

  ##Merge methods
  sampleTemp$method <- ''
  for(methodStr in methodNames){
    patternStr <- sprintf('%%s %s: %%s', methodStr)
    emptyStr <- sprintf('\\s+%s:\\s+$', methodStr)
    sampleTemp$method <- sprintf(patternStr, sampleTemp$method, sampleTemp[,methodStr])
    sampleTemp$method <- gsub(emptyStr, '', sampleTemp$method)
    sampleTemp$method <- gsub('^\\s+', '', sampleTemp$method)
    sampleTemp[,methodStr] <- NULL
  }
  if(verbose) cat('flag1')
  #melt values
  sampleTemp <- unique(melt(sampleTemp, id.vars=c(c('fieldID', 'method'), unitName),
                            variable.name='measurement',
                            na.rm=TRUE, forceNumericValue=TRUE))
  if(verbose) cat('flag2')
  if(!is.null(unitName)){
    names(sampleTemp)[3] <- 'unit'
  }else if(is.null(unitName) & !is.null(unit.df)){
    #units
    sampleTemp <- merge(sampleTemp, unit.df[,c('measurement', 'unit')])
  }else{
    warning('units not specified')
  }
  if(verbose) cat('flag3')
  #issolate unique measurements
  measurementTemp <- unique(sampleTemp[c('measurement','method')])
  measurementTemp$measurementID <- sprintf('%s_%02d', measurementTemp$measurement,
                                           1:nrow(measurementTemp))
  if(verbose) cat('flag4')
  sampleTemp <- merge(sampleTemp, measurementTemp)[, c('fieldID', 'measurementID',
                                                       'value', 'unit')]

  #rename stuff
  names(measurementTemp)[1] <- 'type'

  sampleTemp$value <- as.numeric(sampleTemp$value)
  if(verbose) cat('flag5')
  sampleTemp <- sampleTemp[sampleTemp$value != -999, ]
  if(verbose) cat('flag6')
  return(list(sample=sampleTemp, measurement=measurementTemp))

}