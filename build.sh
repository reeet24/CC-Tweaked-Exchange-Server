mkdir -p deploy
cp startup.lua deploy/
cp server.lua deploy/
cp client_latest.lua deploy/
cp -r modules deploy/modules

cd deploy
for f in $(find . -type f ! -name "manifest.sha256"); do
  hash=$(sha256sum "$f" | cut -d ' ' -f1)
  echo "${f:2} $hash"
done > manifest.sha256
cp manifest.sha256 ../
cd ..
rm -rf deploy 