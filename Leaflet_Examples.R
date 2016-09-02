##### First lets check out a few leaflet examples ####

# You can visit the leaflet home page here http://leafletjs.com/index.html. Note that the Leaflet library 
# was created in JavaScript, and while there is a lot of functionality in the R version, which requires
# no knowledge of JS, you can add a lot to Leaflet (and Shiny) if you do. 

# Here are examples of all the base layers you have freely available:
# https://leaflet-extras.github.io/leaflet-providers/preview/

# I think the Esri.WordTopoMap is my favorite for natural resource type activities because of the topo
# contours, Federal jurisdiction boundary layers, and subdued color scheme which lends itself to overlays.
# But the Iron Maiden theme, Thunderforest.SpinalMap, is also sweet.

# You can overlay points and polygons, and alter their aesthetics: 
# https://www.washingtonpost.com/graphics/national/power-plants/

# Perhaps one of the most useful, though limited, features is the ability to overlay raster data:
# https://www.soilgrids.org/#/?zoom=6&layer=geonode:clyppt_m_sl3_250m

##### Some basic examples in R ####

require(leaflet)

# First lets add one of the provider tiles

map <- leaflet() %>% # R Leaflet uses the "pipe" command to add layers
  addProviderTiles("Esri.WorldTopoMap") 

map

# You can give yourself or the user more than one option

map <- leaflet() %>% 
  # You'll need to assign each layer to a group, lets use the topo map...
  addProviderTiles("Esri.WorldTopoMap", group = "Topo") %>% 
  # ...and an satellite imagery map layer
  addProviderTiles("Esri.WorldImagery", group = "Sat") %>%
  # Next you want to add the control to switch between the two
  addLayersControl(baseGroups = c("Topo","Sat"),
                   options = layersControlOptions(collapsed = F)) 
  #Note that you feed the baseGroups argument your list of groups defined earlier
map

###### Overlay some points ####

# First will get some location data on a native sunflower in our area
# We will use this sweet function from the dismo package that can download organism
# occurrence records from the GBIF database

require(dismo) 
occurrences <- gbif(genus="Heliomeris", species="multiflora", geo=T, removeZeros = T)
#We'll select only those records that have coordinates, year observed, and the collection institution
occurrences <- na.omit(subset(occurrences, select = c("lon", "lat", "year", "institutionCode")))

map.with.markers <- map %>% 
  #the addMarkers function will generate the "pin" marker you typically see in navigation style apps
  addMarkers(lng = occurrences$lon, lat = occurrences$lat)

map.with.markers

# Lets add some popups that tell us what institution collected these data

map.with.popus <- map %>%
  #We do this with the popup argument
  addMarkers(lng = occurrences$lon, lat = occurrences$lat, popup = occurrences$institutionCode)
map.with.popups

# We can also turn our markers on or off

markers.on.off <- map %>% 
  addMarkers(lng = occurrences$lon, lat = occurrences$lat, 
             popup = occurrences$institutionCode, group = "Occurrences") %>%
  addLayersControl(baseGroups = c("Topo","Sat"),
                   overlayGroups = c("Occurrences"),
                   options = layersControlOptions(collapsed = F)) 

# Lets try another marker type that will give us greater control of aesthetics

require(RColorBrewer)

# We will color our occurrences by year observed using the spectral palette from the ColorBrewer package
# Here we define the color palette and values that will be associated with it
spectral <- colorNumeric(palette = rev(brewer.pal(11, "Spectral")), 
                     domain = as.numeric(occurrences$year),
                     na.color = "transparent")

# We will use a new style of marker called the circleMarker

color.by.year <- map %>%
  addCircleMarkers(lng = occurrences$lon, lat = occurrences$lat, color = spectral(occurrences$year),
             popup = occurrences$institutionCode, group = "Occurrences") %>%
  addLayersControl(baseGroups = c("Topo","Sat"),
                   overlayGroups = c("Occurrences"),
                   options = layersControlOptions(collapsed = F)) 
color.by.year

# Lets add a legend so that we can make sense of our rainbow dots
color.by.year.with.leg <- color.by.year %>%
  addLegend("bottomright", pal = spectral , values = occurrences$year,
            title = "Year Observed")

color.by.year.with.leg

##### Adding polygon layers to make a map of the counties in AZ ####

#Loading the polygons 
require(rgdal)
az.census <- readOGR(dsn = "./az_census/gz_2010_04_140_00_500K.shp", layer = "gz_2010_04_140_00_500K")

#Defining a list of hex values for the colors to use in the map
colors <- c("#45b09e",
"#d34695",
"#6cb643",
"#a55ccf",
"#c3ab44",
"#606ecf",
"#5bb070",
"#d14a3b",
"#5e95cf",
"#c27a41",
"#8b5190",
"#6b7b33",
"#ce8dcd",
"#c35e6e")

#This time we use colorFactor to define our palette
county.colors <- colorFactor(palette = colors, 
                         domain = az.census@data$COUNTY,
                         na.color = "transparent")

color.counties <- map %>%
  addPolygons(data = az.census, color = county.colors(az.census@data$COUNTY),
               fillOpacity = 0.75, group = "Counties") %>%
  addLayersControl(baseGroups = c("Topo","Sat"),
                   overlayGroups = c("Counties"),
                   options = layersControlOptions(collapsed = F)) 
color.counties

##### Adding raster data overlays ####

# We will download mean annual temperature data, and crop and mask it to AZ
require(raster)
temp <- tempdir()
MAT <- getData('worldclim', var='bio', path = temp, res=10)[[1]]
az.mask <- spTransform(az.census, CRSobj = crs(MAT))
MAT.AZ <- mask(crop(MAT, az.mask), az.mask)/10

# Leaflet uses a special projection. It will auto-project spatial data appropriately,
# but this can take a long time for larger rasters. I advise projecting raster data first.
# Additionally, load times for rasters larger than 8 megs can be quite slow, even 
# if they are already projected. Something to consider if your end product will be web based. 

# Here we project our AZ temp data for use as a leaflet overlay

MAT.AZ.leaf <- projectRasterForLeaflet(MAT.AZ)

# Quite fast here, because it's a coarse resolution raster. I've noted some strange behaviors with
# the projectRasterForLeaflet() function, in particular, it sometimes messes with the values of
# integers, and you may need to round() certain rasters after projection. 

#We specify color 
spectral.ras <- colorNumeric(palette = rev(brewer.pal(11, "Spectral")), 
                         domain = values(MAT.AZ.leaf), 
                         na.color = "transparent")


ras.map <- leaflet() %>%
  addProviderTiles("Esri.WorldTopoMap", group = "Topo") %>% 
  addProviderTiles("Esri.WorldImagery", group = "Sat") %>%
  #Be sure to set project to False, else it will project the raster again for you
  addRasterImage(MAT.AZ.leaf, colors = spectral.ras, opacity = 0.8, project=FALSE, group = "MAT") %>%
  addLegend("bottomright", pal = spectral.ras , values = values(MAT.AZ.leaf),
            title = "Mean Annual <br> Temperature") %>%
  addLayersControl(baseGroups = c("Topo","Sat"),
                   overlayGroups = c("MAT"),
                   options = layersControlOptions(collapsed = F)) 

ras.map










