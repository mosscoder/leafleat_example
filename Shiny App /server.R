library(leaflet)
library(shiny)
library(rsconnect)




shinyServer(function(input, output, session) {
  
  #You may add additional layers to this leaflet output object
  output$leaf <- renderLeaflet({
    
   map <- leaflet() %>%
      addProviderTiles("Esri.WorldTopoMap", group = "Topo") %>% 
      addProviderTiles("Esri.WorldImagery", group = "Sat") %>%
      addLayersControl(baseGroups = c("Topo","Sat"),
                       options = layersControlOptions(collapsed = F))
    
    map
    
  })
  
  #This observe will add the geolocation of a device to the above map
  observe({
    if(!is.null(input$lat)){
      
      lat <- input$lat
      lng <- input$long
      acc <- input$accuracy
      
      leafletProxy("leaf")  %>% 
        clearGroup(group="pos") %>%
        addMarkers(lng=lng, lat=lat, popup=paste("My location is:","<br>",
                                                 lng,"Longitude","<br>",
                                                 lat,"Latitude", "<br>",
                                                 "My accuracy is:",  "<br>",
                                                 acc, "meters"), group="pos") %>%
        addCircles(lng=lng, lat=lat, radius=acc, group="pos") 
      
    }
    
  })
  
  
})