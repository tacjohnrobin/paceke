import { encodeGeohash } from '../utils/geohash.util.js';
import { haversineDistance } from '../utils/haversine.util.js';

const lat1 = -1.2921;
const lng1 = 36.8219;

// ~100m away point
const lat2 = -1.2915;
const lng2 = 36.8223;

// Distance test
const distance = haversineDistance(lat1, lng1, lat2, lng2);

console.log('Distance (m):', distance);

// Geohash test
const hash1 = encodeGeohash(lat1, lng1, 7);
const hash2 = encodeGeohash(lat2, lng2, 7);

console.log('Geohash 1:', hash1);
console.log('Geohash 2:', hash2);
