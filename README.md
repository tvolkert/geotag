# geotag

A Flutter desktop client for locally geotagging photos (by updating their EXIF
info).

Currently only designed to run on macOS -- `flutter run -d macos`

# Current state

Trying to get the web-view to work.  To get to the screen where the web-view
_should_ show up, click the icon in the upper-left of the window, then choose
a JPG photo from your computer. Once you've chosen it, select it in the lower
list view of photo thumbnails.  The photo will then be shown in the main display area, and to the right of the photo, there'll be a column with the photo's
path, a text input that's populated with the photo's GPS coordinates, and
finally, a web-view... except the webview isn't showing up... it's just a white
box...
