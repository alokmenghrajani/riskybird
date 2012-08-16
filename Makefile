OPA=opa
OPAPLUGIN=opa-plugin-builder

SRC= \
 	parsing/parser.opa \
	parsing/assign_id.opa \
  	pretty_printers/string_printer.opa \
  	pretty_printers/highlight_string_printer.opa \
	pretty_printers/svg_printer.opa \
	lint/lint.opa \
	lint/fix.opa \
	lint/escaped_char.opa \
	lint/character_class.opa \
	utils/anchors.opa \
	utils/misc.opa \
	utils/group_regexp.opa \
    utils/test.opa

default: run

run: riskybird.exe
	./riskybird.exe

test: riskybird_unittest.exe
	./riskybird_unittest.exe

riskybird.exe: $(SRC) resources/riskybird.css riskybird.opa
	$(OPA) -o riskybird.exe $(SRC) riskybird.opa

riskybird_unittest.exe: $(SRC) unittest.opa
	$(OPA) --no-server -o riskybird_unittest.exe $(SRC) unittest.opa

clean:
	rm -Rf *~ *.exe *.log _build/ *.opp *.js parsing/*.js pretty_printers/*.js utils/*.js lint/*.js _tracks/

$(SRC):

%.opp: %.js
	$(OPAPLUGIN) -o $(@:.opp=) $<
