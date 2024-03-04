% Plot lat/lon data from FaceBook POEM v3.1 data

geoplot(latVal,lonVal,'o','MarkerSize',8,'MarkerEdgeColor','none','MarkerFaceColor',[1 0 0]);
geobasemap darkwater
geolimits([25 50],[-130 -60]);
