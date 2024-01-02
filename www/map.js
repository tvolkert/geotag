async function initMap() {
  const { Map } = await google.maps.importLibrary("maps");
  const { AdvancedMarkerElement } = await google.maps.importLibrary("marker");
  const { SearchBox } = await google.maps.importLibrary("places");

  const urlParams = new URLSearchParams(window.location.search);
  const initialCoords = urlParams.get('initial');
  let myLatlng = null;
  if (initialCoords == null) {
    myLatlng = { lat: 48.8601, lng: 2.3446 };
  } else {
    var coords = initialCoords.split(",");
    myLatlng = { lat: parseFloat(coords[0]), lng: parseFloat(coords[1]) };
  }

  const map = new Map(document.getElementById("map"), {
    center: myLatlng,
    zoom: 19,
    disableDefaultUI: true,
    zoomControl: true,
    mapTypeId: 'satellite',
    // scaleControl: true,
    mapId: 'b56906ff9307a9d8',
  });

  let draggableMarker = null;
  function placePinAt(latlng) {
    if (draggableMarker == null) {
      draggableMarker = new AdvancedMarkerElement({
        map,
        position: latlng,
        gmpDraggable: true,
        title: "Drag marker to update location.",
      });

      draggableMarker.addListener("dragend", (event) => {
        const position = draggableMarker.position;
        map.panTo(position);
      });
    }

    draggableMarker.position = latlng;
    map.panTo(latlng);
  }

  if (myLatlng != null) {
    placePinAt(myLatlng);
  }

  let timeoutId = null;
  function updateHash(latlng) {
    timeoutId = null;
    window.history.replaceState(undefined, undefined, "#" + latlng.lat() + "," + latlng.lng());
  }
  map.addListener("center_changed", () => {
    if (timeoutId != null) {
      window.clearTimeout(timeoutId);
    }
    timeoutId = window.setTimeout(updateHash,100,map.getCenter());
  });

//  window.setInterval(function(){
//    var center = map.getCenter();
//    map.panTo(new google.maps.LatLng(center.lat(), center.lng() + 0.1));
//  }, 5000);

  // Create the search box and link it to the UI element.
  const input = document.getElementById("pac-input");
  const searchBox = new google.maps.places.SearchBox(input);

  map.controls[google.maps.ControlPosition.TOP_LEFT].push(input);
  // Bias the SearchBox results towards current map's viewport.
  map.addListener("bounds_changed", () => {
    searchBox.setBounds(map.getBounds());
  });

  searchBox.addListener("places_changed", () => {
    const places = searchBox.getPlaces();

    if (places.length == 0) {
      return;
    }

    if (places.lenth > 1) {
      console.log("More than one returned place");
      return;
    }

    const place = places[0];
    if (!place.geometry || !place.geometry.location) {
      console.log("Returned place contains no geometry");
      return;
    }

    placePinAt(place.geometry.location);
  });

  window.rePin = function(coords) {
    var splitCoords = coords.split(",");
    let latlng = { lat: parseFloat(splitCoords[0]), lng: parseFloat(splitCoords[1]) };
    placePinAt(latlng);
  };
}

initMap();
