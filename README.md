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

Elaborado por Marcelo Camargo em 09/06/2016