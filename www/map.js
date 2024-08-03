async function initMap() {
  const { LatLng, LatLngBounds } = await google.maps.importLibrary("core")
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
      let position = new LatLng({
        lat: parseFloat(splitCoords[0]),
        lng: parseFloat(splitCoords[1]),
      });
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

  function getBoundsZoomLevel(bounds) {
    var WORLD_DIM = { height: 256, width: 256 };
    var ZOOM_MAX = 21;

    function latRad(lat) {
      var sin = Math.sin(lat * Math.PI / 180);
      var radX2 = Math.log((1 + sin) / (1 - sin)) / 2;
      return Math.max(Math.min(radX2, Math.PI), -Math.PI) / 2;
    }

    function zoom(mapPx, worldPx, fraction) {
      // return Math.floor(Math.log(mapPx / worldPx / fraction) / Math.LN2);
      return Math.log(mapPx / worldPx / fraction) / Math.LN2;
    }

    var ne = bounds.getNorthEast();
    var sw = bounds.getSouthWest();

    var latFraction = (latRad(ne.lat()) - latRad(sw.lat())) / Math.PI;

    var lngDiff = ne.lng() - sw.lng();
    var lngFraction = ((lngDiff < 0) ? (lngDiff + 360) : lngDiff) / 360;

    let offsetWidth = mapElement.offsetWidth;
    if (offsetWidth == 0) {
      offsetWidth = 256;
    }
    let offsetHeight = mapElement.offsetHeight;
    if (offsetHeight == 0) {
      offsetHeight = 256;
    }
    var latZoom = zoom(offsetHeight, WORLD_DIM.height, latFraction);
    var lngZoom = zoom(offsetWidth, WORLD_DIM.width, lngFraction);

    return Math.min(latZoom, lngZoom, ZOOM_MAX);
  }

  function lerpDouble(a, b, t) {
    if (a == b || (isNaN(a) && isNaN(b))) {
      return a;
    }
    return a * (1.0 - t) + b * t;
  }

  function lerpBounds(a, b, t) {
    if (a === b) {
      return a;
    }
    return new LatLngBounds({
      east: lerpDouble(a.getNorthEast().lng(), b.getNorthEast().lng(), t),
      north: lerpDouble(a.getNorthEast().lat(), b.getNorthEast().lat(), t),
      south: lerpDouble(a.getSouthWest().lat(), b.getSouthWest().lat(), t),
      west: lerpDouble(a.getSouthWest().lng(), b.getSouthWest().lng(), t),
    });
  }

  function lerpPosition(a, b, t) {
    if (a === b) {
      return a;
    }
    return new LatLng({
      lat: lerpDouble(a.lat(), b.lat(), t),
      lng: lerpDouble(a.lng(), b.lng(), t),
    });
  }

  function easeOutSine(x) {
    return Math.sin((x * Math.PI) / 2);
  }

  function easeInSine(x) {
    return 1 - Math.cos((x * Math.PI) / 2);
  }

  function easeInOutSine(x) {
    return -(Math.cos(Math.PI * x) - 1) / 2;
  }

  function easeOutCubic(x) {
    return 1 - Math.pow(1 - x, 3);
  }

  function easeInCubic(x) {
    return x * x * x;
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
    zoom: getBoundsZoomLevel(bounds),
    disableDefaultUI: true,
    zoomControl: true,
    mapTypeId: 'satellite',
    // scaleControl: true,
    mapId: 'b56906ff9307a9d8',
  });
  window.map = map; // TODO: remove

  let timeoutId = null;
  let animatingToCenter = null;
  function animateToBounds(targetBounds) {
    let start = new Date().getTime();
    const sourceCenter = map.getCenter();
    const sourceZoom = map.getZoom();
    const targetCenter = targetBounds.getCenter();
    const targetZoom = getBoundsZoomLevel(targetBounds) - 0.75;

    if (timeoutId != null) {
      if (targetCenter.lat() == animatingToCenter.lat() && targetCenter.lng() == animatingToCenter.lng()) {
        // Leave the existing animation alone
        return;
      } else {
        window.clearTimeout(timeoutId);
        timeoutId = null;
      }
    }
    animatingToCenter = targetCenter;

    const duration = 1200;
    const delay = 25;
    let easeZoom = targetZoom > sourceZoom ? easeInCubic : easeOutCubic;
    let easeCenter = targetZoom > sourceZoom ? easeOutSine : easeInOutSine;

    function tick() {
      let now = new Date().getTime();
      let diff = now - start;
      let t = Math.min(diff / duration, 1);
      let center = lerpPosition(sourceCenter, targetCenter, easeCenter(t));
      let zoom = lerpDouble(sourceZoom, targetZoom, easeZoom(t));
      map.moveCamera({
        center: center,
        zoom: zoom,
      });
      if (t < 1) {
        timeoutId = window.setTimeout(tick, delay);
      } else {
        timeoutId = null;
        animatingToCenter = null;
      }
    }

    timeoutId = window.setTimeout(tick, delay);
  }

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
          Geotag.postMessage("latlng:" + position.lat + "," + position.lng);
        }
      });
    }

    draggableMarker.position = position;
    if (map.getBounds() === undefined) {
      map.setCenter(position);
      let bounds = getBounds([position]);
      let zoom = getBoundsZoomLevel(bounds);
      map.setZoom(zoom);
    } else {
      animateToBounds(getBounds([position]));
    }
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
    const zoom = getBoundsZoomLevel(bounds);
    if (map.getBounds() === undefined) {
      map.setCenter(bounds.getCenter());
      map.setZoom(zoom);
    } else {
      animateToBounds(bounds);
    }
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
