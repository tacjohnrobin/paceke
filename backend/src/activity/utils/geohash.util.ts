import ngeohash from "ngeohash";

export function pointToGeohash(
  lat: number,
  lng: number,
  precision: number
): string {
  return ngeohash.encode(lat, lng, precision);
}
