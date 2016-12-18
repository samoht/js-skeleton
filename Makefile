# make JFLAGS="--pretty --noinline"
JFLAGS =

# Let ocamlbuild work out the dependencies.
.PHONE: build-byte

_build/main.js: build-byte
	js_of_ocaml ${JFLAGS} +weak.js _build/main.byte
	browse index.html

build-byte:
	ocamlbuild -cflag -g -no-links -use-ocamlfind main.byte

clean:
	ocamlbuild -clean
