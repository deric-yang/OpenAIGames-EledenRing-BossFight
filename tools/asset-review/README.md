# Local source-asset review

Run `node tools/asset-review/build.mjs` from the project, then serve **builds/web** on 127.0.0.1:8093. Open `/asset-review/`.

The build copies only curated source GLBs, review PNGs and public metadata. It never copies credentials or API response files. Models are static high-detail sources, not production game meshes.

Viewer: Google [model-viewer](https://modelviewer.dev/) 4.3.1, Apache-2.0. Vendored from the official CDN `https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js`; license in `vendor/LICENSE` from the official v4.3.1 repository. Local JS avoids requiring CDN connectivity during review.
