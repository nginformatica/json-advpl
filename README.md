## AdvPL JSON Parser

Copyright (C) 2016 NG Informática - TOTVS Software Partner

### Instalação
Compile o arquivo `JSON.prw` no repositório e adicione o arquivo `json.ch` à pasta de *includes*.

### Inclusão de arquivos
```
#include 'json.ch'
```

### Interfaces
```
Class JSON
   Method New( xData ) Constructor
   Method Parse()
   Method Stringify()
   Method Minify()
   Method File()
EndClass
```

### Casos de uso

A maneira mais simpels de utilizar é usando a função `ParseJSON`. Ela recebe
o JSON atual como string e uma referência para o objeto que será a saída.
Retorna `.T.` quando o JSON é analisado com sucesso e `.F.` quando há um erro
sintático, também atribuindo o erro à referência à variável passada.

#### Parsear JSON simples
```delphi
Local cJSON := '{"n": 1}'
Local oJSON

If ParseJSON( cJSON, @oJSON )
  Console( oJSON[#'n'] ) // 1
Else
  Console( oJSON ) // Erro como string, se houver
EndIf
```

#### Minificar um JSON existente
```delphi
Local cJSON     := '{  "some":   true, [ "big", 1 ] }'
Local cMinified := JSON():New( cJSON ):Minify()
// '{"some":true,["big",1]}'
```

#### Parsear uma string JSON
```delphi
Local oParser := JSON():New( '{ "data": [ { "name": "John", "age": 19 } ] }' ):Parse()

If oParser:IsJSON()
   // "John"
   oParser:Object()[#'data'][ 1 ][#'name']
   // 19
   oParser:Object()[#'data'][ 1 ][#'age']
Else
   // Em caso de erro
   ConOut( oParser:Error() )
EndIf
```

Você também pode acessar objetos via `:Get('name')` ao invés de `[#'name']` e definir com `:Set('name', 'Marcelo')` ao invés de `[#'name'] := 'Marcelo'`.

#### Analisar arquivo JSON
```json
{
  "key":"all",
  "description":"Todas as permissões",
  "children":[
    {
      "key":"create_order",
      "description":"Incluir O.S.",
      "children":[
        {
          "key":"create_order_corr",
          "description":"Corretiva"
        },
        {
          "key":"create_order_prev",
          "description":"Preventiva"
        }
      ]
    },
    {
      "key":"edit_order",
      "description":"Alterar O.S.", [ ... ]
```

```delphi
Local oParser := JSON():New( './main.json' ):File():Parse()
// "Corretiva"
oParser:Object()[#'children'][ 1 ][#'children'][ 1 ][#'description']
```

#### Transformar um objeto em uma string

A biblioteca provê um objeto para conversão. Use a class `JSON` para isso.
```delphi
Local oJSON := JSONObject():New()

oJSON[#'data'] := { }
oJSON[#'sub' ] := 12.4

aAdd( oJSON[#'data'], JSONObject():New() )

oJSON[#'data'][ 1 ][#'name'] := 'Marcelo'
oJSON[#'data'][ 1 ][#'age']  := 19
// {"data":[{"name":"Marcelo","age":19}],"sub":12.4}
JSON():New( oJSON ):Stringify()
```

#### Ler e escrever dados por JSON
```delphi
Function JSONFromST1
  Local aResults := { }
  Local nI   := 1

  dbSelectArea( 'ST1' )
  dbGoTop()

  While !Eof()
    aAdd( aResults, JSONObject():New() )
    aResults[ nI ][#'codigo'] := ST1->T1_CODFUNC
    aResults[ nI ][#'nome']   := ST1->T1_NOME
    nI++
    dbSkip()
  End

  dbCloseArea()

  Return JSON():New( aResults ):Stringify()

Function JSONToST1( cJSON )
  Local oParser := JSON():New( cJSON ):Parse()
  Local oJSON

  If oParser:IsJSON()
    aJSON := oParser:Object()

    dbSelectArea( 'ST1' )
    For nI := 1 To Len( aJSON )
      RecLock( 'ST1', .T. )
      ST1->T1_CODIGO := aJSON[ nI ][#'codigo']
      ST1->T1_NOME   := aJSON[ nI ][#'nome']
      MsUnlock()
    Next nI
    dbCloseArea()

  Else
    Return .F.
  EndIf

  Return .T.

Function WriteMetaData
  Return JSONToST1( '[{"nome":"Richard", "codigo": "01"},{"nome":"John","codigo":"02"}]' )
```

Elaborado por Marcelo Camargo em 09/06/2016
