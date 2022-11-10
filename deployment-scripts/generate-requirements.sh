for d in code/lambda/* ; do
  (cd "$d" && poetry export --without-hashes -o requirements.txt)
done