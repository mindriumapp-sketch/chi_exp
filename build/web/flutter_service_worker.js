'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "1f41852f2d2f2aee7c0923f6c871e21d",
"version.json": "37079ee17435075e3a53771d4a523a2e",
"splash/img/light-2x.png": "7311f170287c95864f66d8ead905caf2",
"splash/img/dark-4x.png": "0a1c413e7f708d93d930551f9f8dd8d0",
"splash/img/light-3x.png": "c4c4dcfab6e6b6cd2264d4dd095d24cf",
"splash/img/dark-3x.png": "c4c4dcfab6e6b6cd2264d4dd095d24cf",
"splash/img/light-4x.png": "0a1c413e7f708d93d930551f9f8dd8d0",
"splash/img/dark-2x.png": "7311f170287c95864f66d8ead905caf2",
"splash/img/dark-1x.png": "c9a6213c374d2f41f0437358dd99b13d",
"splash/img/light-1x.png": "c9a6213c374d2f41f0437358dd99b13d",
"index.html": "613eff261c57b8ce2f5eff4913931584",
"/": "613eff261c57b8ce2f5eff4913931584",
"main.dart.js": "e6a739666c6e17f565cf62e4a0c8d1af",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "fd091ea5bc8f3ccc10f74bd67179fb6a",
"assets/AssetManifest.json": "8fed519ab6123bb5993d0fed0f44909b",
"assets/NOTICES": "6d675255ed7eb70e92374cb9bbf56979",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "961d8ff35491b735f922302625693fc9",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "fec67171f7a705615fe39badfc5dcf30",
"assets/fonts/MaterialIcons-Regular.otf": "baa5ead244c53d87dbd4beb8b0967af1",
"assets/assets/education_data/week1_part4_1.json": "316c96c5f45a9d81ec461762cdfa9a70",
"assets/assets/education_data/week1_part1_2.json": "f022df3110c6af51d7c5d9b9b5aef56f",
"assets/assets/education_data/week1_part5_5.json": "1d704ec62e89e2e96f873b5bdf100c30",
"assets/assets/education_data/week1_part3_3.json": "e9f01a036c30deb43c5644005b53d65e",
"assets/assets/education_data/week1_part3_2.json": "c5f0548314397c932215399dbd89005f",
"assets/assets/education_data/week1_part6_1.json": "e4538c9d288250d926c16334ee048e3f",
"assets/assets/education_data/week1_part5_4.json": "42a58663d4a3481fd4878dbc24ba6d4b",
"assets/assets/education_data/week1_part1_3.json": "96cda824712e55bb03b611beed732e90",
"assets/assets/education_data/week1_part1_4.json": "561853d283f31b73fa2487a96caa453c",
"assets/assets/education_data/week1_part5_3.json": "182043a6921c5e13c43766298444a1f5",
"assets/assets/education_data/week1_part2_1.json": "143eef66f03e97af4ea455a88a5e6ac6",
"assets/assets/education_data/week1_part3_5.json": "2960be4d94241549bb9ba90670398c00",
"assets/assets/education_data/week1_part3_9.json": "b66ba178e26514ccdecd5f50c20ebb42",
"assets/assets/education_data/week1_part3_8.json": "3f48f43fc0d153868d374c5235b26e95",
"assets/assets/education_data/week1_part3_4.json": "09d5646be6359dc922befb137f64c773",
"assets/assets/education_data/week1_part5_2.json": "695dacebe2f6082f6d3ddf61469e8874",
"assets/assets/education_data/week1_part1_5.json": "bc5a092fc769d2631a000ba6ea226afa",
"assets/assets/education_data/week1_part4_6.json": "ecf3165cfee942805fd3273edf79e9a0",
"assets/assets/education_data/week1_part3_7.json": "f51473e61aaa9f679699eb037f08c85c",
"assets/assets/education_data/week1_part6_4.json": "a0919767754827446a121dd28ab7d0ba",
"assets/assets/education_data/week1_part2_3.json": "4bf4f9628ffba2e0a64c1ea6c3ce660b",
"assets/assets/education_data/week1_part5_1.json": "8d9d8585a8c6978c4c5008774e285654",
"assets/assets/education_data/week1_part1_6.json": "5373e3832284fa962d57682e39434235",
"assets/assets/education_data/week1_part4_5.json": "9ac171582c52d08b886665310e6bf97e",
"assets/assets/education_data/week1_part4_4.json": "e1f5b69a276be073a64a03586c540830",
"assets/assets/education_data/week1_part2_2.json": "ad4e83d9468d402522a3b4e0988d0cf5",
"assets/assets/education_data/week1_part3_6.json": "e2fde9e461954b6c9110755077e926f5",
"assets/assets/education_data/week1_part3_1.json": "d7f255a1e295e9efbd32b938333d09e7",
"assets/assets/education_data/week1_part6_2.json": "9ca619326e358ee8bc7eae9f0682bd34",
"assets/assets/education_data/week1_part5_7.json": "6c0352dce479984bcdac0597e28b98b4",
"assets/assets/education_data/week1_part4_3.json": "73d1f071d31e543ba75054b53019669e",
"assets/assets/education_data/week1_part4_2.json": "794608f0330a21e2bebc62904bbd4a44",
"assets/assets/education_data/week1_part1_1.json": "ee42cc5040c855e5da80f668977255fc",
"assets/assets/education_data/week1_part5_6.json": "84f0c3789ddfe3aedc2e7fc156e72f60",
"assets/assets/education_data/week1_part6_3.json": "f6d71e96c9013c9797acb9177235cb7e",
"assets/assets/image/imagination.png": "29204c6d826855e43e3512600b802917",
"assets/assets/image/character5.png": "79d369284ca169d9f1714af1a3d400b7",
"assets/assets/image/character4.png": "45a9feeb53e98243d4747b95e1d74a1b",
"assets/assets/image/character6.png": "ed64b7e9aeb6416db2d64a0c53c63b2a",
"assets/assets/image/character7.png": "33b10122791863101730dfad41bd7a0a",
"assets/assets/image/character3.png": "cca7356f6ddcb28cc88b82810f71a0c5",
"assets/assets/image/character2.png": "c1ad4130a2ba8f9fc77fbedbcadd6679",
"assets/assets/image/character1.png": "69943c3c4b94d14ceaa35092bde97d5b",
"assets/assets/image/logo.png": "537fee5423d63134202907965b7d3137",
"assets/assets/image/belief.png": "42f93b5b9f9e7491d20ee4ed66255b85",
"assets/assets/image/consequence.png": "651d0773e3972847a470f2eb5ab5893a",
"assets/assets/image/character9.png": "91eacb1fd0e50264c1906667214a036e",
"assets/assets/image/character8.png": "8cff277834de1445abbb9355ab7f311d",
"assets/assets/image/nice.png": "80d573642f436b029572026bcff57b8c",
"assets/assets/image/question_icon.png": "29c404c67b798a07b47523495e06d7e4",
"assets/assets/image/alternative%2520thoughts.png": "3c3fe7adab24b5435084c3b42116ba84",
"assets/assets/image/activating%2520event.png": "7e0ea7eaa71ad39fef8a8a83fce03ba7",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
