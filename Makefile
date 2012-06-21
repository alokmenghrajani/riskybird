
OPA=opa --parser js-like
OPAPLUGIN=opa-plugin-builder

SRC= \
  riskybird_parser.opa \
	riskybird_assign_id.opa \
  riskybird_string_printer.opa \
  riskybird_xhtml_printer.opa \
  riskybird_svg_printer.opa \
  riskybird_eval.opa \
  riskybird_lint.opa \
	riskybird_fix.opa \
	riskybird_utils.opa

BINDINGS= \
  riskybird_binding.js

BINDINGS_OBJ=$(BINDINGS:.js=.opp)

default: run

run: riskybird.exe
	./riskybird.exe

run2: riskybird2.exe
	./riskybird2.exe

test: riskybird_unittest.exe
	./riskybird_unittest.exe

riskybird.exe: $(BINDINGS_OBJ) $(SRC) riskybird.opa
	$(OPA) -o riskybird.exe $(SRC) riskybird.opa

riskybird2.exe: $(BINDINGS_OBJ) $(SRC) riskybird2.opa
	$(OPA) -o riskybird2.exe $(SRC) riskybird2.opa


riskybird_unittest.exe: $(BINDINGS_OBJ) $(SRC) riskybird_unittest.opa
	$(OPA) -o riskybird_unittest.exe $(SRC) riskybird_unittest.opa

clean:
	rm -Rf *~ *.exe *.log _build/ *.opp


%.opp: %.js
	$(OPAPLUGIN) -o $(@:.opp=) $<
