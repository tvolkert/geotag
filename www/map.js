async function initMap() {
  const { LatLngBounds } = await google.maps.importLibrary("core")
  const { Map, InfoWindow } = await google.maps.importLibrary("maps");
  const { AdvancedMarkerElement, PinElement } = await google.maps.importLibrary("marker");
  const { SearchBox } = await google.maps.importLibrary("places");

  const placeholderElement = document.getElementById("placeholder");
  const mapElement = document.getElementById("map");
  const inputElement = document.getElementById("pac-input");

  function parsePositions(allCoords) {
    const positions = [];
    let entries = allCoords.split(";");
    for (let i in entries) {
      let coords = entries[i];
      var splitCoords = coords.split(",");
      let position = { lat: parseFloat(splitCoords[0]), lng: parseFloat(splitCoords[1]) };
      positions.push(position);
    }
    return positions;
  }

  function getBounds(positions) {
    var bounds = new google.maps.LatLngBounds();
    for (var i = 0; i < positions.length; i++) {
      bounds.extend(positions[i]);
    }
    return bounds;
  }

  function smoothZoom(map, target, current) {
    if (current === undefined) {
      current = map.getZoom();
    }
    if (current >= target) {
      return;
    }
    let targetCeiling = Math.min(target, 20);
    if (targetCeiling - current > 7) {
      // Too far to animate; it wouldn't look good.
      let jumpTarget = targetCeiling - 3;
      map.setZoom(jumpTarget);
      smoothZoom(map, target, jumpTarget);
      return;
    }
    else {
      var lsnr = google.maps.event.addListener(map, 'zoom_changed', function(event) {
        google.maps.event.removeListener(lsnr);
        smoothZoom(map, target, current + 1);
      });
      setTimeout(function() {
        map.setZoom(current);
      }, 120);
    }
  }

  const urlParams = new URLSearchParams(window.location.search);
  const initialCoords = urlParams.get('initial');
  let initialPositions = [];
  if (initialCoords == null) {
    placeholderElement.style.display = "block";
  } else {
    mapElement.style.display = "block";
    initialPositions = parsePositions(initialCoords);
  }

  const bounds = getBounds(initialPositions);
  const map = new Map(mapElement, {
    center: bounds.getCenter(),
    zoom: 19,
    disableDefaultUI: true,
    zoomControl: true,
    mapTypeId: 'satellite',
    // scaleControl: true,
    mapId: 'b56906ff9307a9d8',
  });
  map.fitBounds(bounds);

  let draggableMarker = null;
  function placeSinglePin(position) {
    clearMultiplePins();

    if (draggableMarker == null) {
      draggableMarker = new AdvancedMarkerElement({
        map,
        position: position,
        gmpDraggable: true,
        title: "Drag marker to update location.",
      });

      draggableMarker.addListener("dragend", (event) => {
        const position = draggableMarker.position;
        map.panTo(position);
        if (window.Geotag) {
          Geotag.postMessage("latlng:" + position.lat() + "," + position.lng());
        }
      });
    }

    draggableMarker.position = position;
    map.panTo(position);
    window.setTimeout(function() {
      smoothZoom(map, 30);
    }, 500);
    window.map = map;
  }

  function clearSinglePin() {
    if (draggableMarker != null) {
      draggableMarker.setMap(null);
      draggableMarker = null;
    }
  }

  let multipleMarkers = [];
  function placeMultiplePins(positions) {
    clearSinglePin();
    clearMultiplePins();
    const infoWindow = new google.maps.InfoWindow({
      content: "",
      disableAutoPan: true,
    });
    for (let i = 0; i < positions.length; i++) {
      let position = positions[i];
      let glyph = i + 1;
      const pinGlyph = new google.maps.marker.PinElement({
        glyph: glyph.toString(),
        glyphColor: "white",
      });
      const marker = new google.maps.marker.AdvancedMarkerElement({
        map,
        position,
        content: pinGlyph.element,
      });
      marker.addListener("click", () => {
        infoWindow.setContent(position.lat + ", " + position.lng);
        infoWindow.open(map, marker);
      });
      multipleMarkers.push(marker);
    }
    const bounds = getBounds(positions);
    map.fitBounds(bounds);
    // new MarkerClusterer({ multipleMarkers, map });
  }

  function clearMultiplePins() {
    for (let i = 0; i < multipleMarkers.length; i++) {
      multipleMarkers[i].setMap(null);
    }
    multipleMarkers = [];
  }

  if (initialPositions.length == 1) {
    placeSinglePin(initialPositions[0]);
  } else if (initialPositions.length > 1) {
    placeMultiplePins(initialPositions);
  }

  // let timeoutId = null;
  // function updateHash(latlng) {
  //   timeoutId = null;
  //   window.history.replaceState(undefined, undefined, "#" + latlng.lat() + "," + latlng.lng());
  // }
  // map.addListener("center_changed", () => {
  //   if (timeoutId != null) {
  //     window.clearTimeout(timeoutId);
  //   }
  //   timeoutId = window.setTimeout(updateHash,100,map.getCenter());
  // });

  // Create the search box and link it to the UI element.
  const searchBox = new google.maps.places.SearchBox(inputElement);

  // Bias the SearchBox results towards current map's viewport.
  map.controls[google.maps.ControlPosition.TOP_LEFT].push(inputElement);
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

    placeholderElement.style.display = "none";
    mapElement.style.display = "block";
    placeSinglePin(place.geometry.location);
  });

  window.rePin = function(allCoords) {
    if (allCoords == null) {
      mapElement.style.display = "none";
      placeholderElement.style.display = "block";
    } else {
      mapElement.style.display = "block";
      placeholderElement.style.display = "none";
      const positions = parsePositions(allCoords);
      if (positions.length == 1) {
        placeSinglePin(positions[0]);
      } else {
        placeMultiplePins(positions);
      }
    }
  };
}

window.onerror = function myErrorHandler(errorMsg) {
  if (window.Geotag) {
    Geotag.postMessage("print:" + errorMsg);
    return true;
  }
  return false;
};

initMap()
  .then((value) => {
    if (window.Geotag) {
      Geotag.postMessage("loaded:1");
    }
  });
