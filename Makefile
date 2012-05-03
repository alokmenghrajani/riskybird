
OPA=opa --parser js-like
OPAPLUGIN=opa-plugin-builder

SRC= \
  riskybird_eval.opa \
  riskybird_lint.opa \
  riskybird_parser.opa \
  riskybird_string_printer.opa \
  riskybird_xhtml_printer.opa \
  riskybird.opa

BINDINGS= \
  riskybird_binding.js

BINDINGS_OBJ=$(BINDINGS:.js=.opp)

default: run

run: riskybird.exe
	./riskybird.exe

riskybird.exe: $(BINDINGS_OBJ) $(SRC)
	opa --parser js-like -o riskybird.exe *.op?

clean:
	rm -Rf *~ *.exe *.log _build/ *.opp


%.opp: %.js
	$(OPAPLUGIN) -o $(@:.opp=) $<
