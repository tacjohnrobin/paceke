// src/utils/haversine.util.ts

const EARTH_RADIUS_M = 6371000; // meters

function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180);
}

/**
 * Computes great-circle distance between two GPS points
 * great-circle-d using the Haversine formula.
 *
 * returns distance in meters
 */
export function haversineDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {

  if (
    lat1 === lat2 &&
    lng1 === lng2
  ) {
    return 0;
  }

  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);

  const rLat1 = toRadians(lat1);
  const rLat2 = toRadians(lat2);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(rLat1) *
      Math.cos(rLat2) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(
    Math.sqrt(a),
    Math.sqrt(1 - a)
  );

  return EARTH_RADIUS_M * c;
}
