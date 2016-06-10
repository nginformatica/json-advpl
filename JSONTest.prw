/**
 * BEGIN SECTION TEST
 */
Static Function TestMinify
  Local cJSON     := '{    "some":      true,      [ "big", 1 ] }'
  Local cMinified := JSON():New( cJSON ):Minify()

  OutStd( cMinified == '{"some":true,["big",1]}' )
  Return

Static Function TestParse
  Local oParser := JSON():New( '{ "data": [ { "name": "Marcelo", "age": 19 } ] }' ):Parse()

  If oParser:IsJSON()
    OutStd( oParser:Object()[#'data'][ 1 ][#'name'] == "Marcelo" )
    OutStd( oParser:Object()[#'data'][ 1 ][#'age'] == 19 )
  Else
    OutStd( oParser:Error() )
  EndIf
  Return

Static Function TestFile()
  Local oParser := JSON():New( './json/main.json' ):File():Parse()

  If oParser:IsJSON()
    OutStd( oParser:Object()[#'children'][ 1 ][#'children'][ 1 ][#'description'] == 'Corretiva' )
  Else
    OutStd( oParser )
  EndIf
  Return

Static Function TestStringify()
  Local oJSON := JSONObject():New()

  oJSON[#'data'] := { }
  oJSON[#'sub' ] := 12.4

  aAdd( oJSON[#'data'], JSONObject():New() )

  oJSON[#'data'][ 1 ][#'name'] := 'Marcelo'
  oJSON[#'data'][ 1 ][#'age']  := 19

  OutStd( JSON():New( oJSON ):Stringify() == '{"data":[{"name":"Marcelo","age":19}],"sub":12.4}' )
  Return

/// TESTS!
Function Main
  TestMinify()
  TestParse()
  TestFile()
  TestStringify()
  Return
