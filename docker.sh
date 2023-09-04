#!/usr/bin/bash
[[ -d "build" ]] && rm -rf build
mkdir build
shopt -s extglob
cp -R !(build) build
docker build --rm -t sectpmctl-builder --build-arg="USER_ID=$UID" .
docker run --user=$UID --rm -v ./:/work sectpmctl-builder /usr/bin/bash -c "cd /work/build && debuild -i -uc -us -b"
rm -rf build
rm *.build
rm *.buildinfo
rm *.changes
rm *.ddeb