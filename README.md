## AdvPL JSON Parser

Copyright (C) 2016 NG Informática - TOTVS Software Partner

<div align="center" style="width: 100%">
   <div>
      <img src="https://s3.amazonaws.com/media-p.slid.es/uploads/kouceylahadji-1/images/174949/json_logo-555px__1_.png" />
   </div>
   <img src="https://img.shields.io/badge/language-advpl-green.svg" />
</div>

### Instalação
Compile o arquivo `src/JSON.prw` no repositório e adicione o arquivo `includes/json.ch` à pasta de *includes*.

### Inclusão de arquivos
```xbase
#include 'json.ch'
```

### Interfaces
```xbase
Class JSON
   Method New( xData ) Constructor
   Method Parse()
   Method Stringify()
   Method Minify()
   Method File()
EndClass
```

### Casos de uso

A maneira mais simples de utilizar é usando a função `U_ParseJSON`. Ela recebe
o JSON atual como string e uma referência para o objeto que será a saída.
Retorna `.T.` quando o JSON é analisado com sucesso e `.F.` quando há um erro
sintático, também atribuindo o erro à referência à variável passada.

#### Parsear JSON simples
```xbase
Local cJSON := '{"n": 1}'
Local oJSON

If U_ParseJSON( cJSON, @oJSON )
  ConOut( oJSON[#'n'] ) // 1
Else
  ConOut( oJSON ) // Erro como string, se houver
EndIf
```

#### Minificar um JSON existente
```xbase
Local cJSON     := '{  "some":   true, [ "big", 1 ] }'
Local cMinified := JSON():New( cJSON ):Minify()
// '{"some":true,["big",1]}'
```

#### Parsear uma string JSON
```xbase
Local oParser := JSON():New( '{ "data": [ { "name": "John", "age": 19 } ] }' )
oParser := oParser:Parse()

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
    }
  ]
}
```

```xbase
Local oParser := JSON():New( './main.json' )
oParser := oParser:File():Parse()
// "Corretiva"
oParser:Object()[#'children'][ 1 ][#'children'][ 1 ][#'description']
```

#### Transformar um objeto em uma string

A biblioteca provê um objeto para conversão. Use a class `JSON` para isso.
```xbase
Local oJSON := JSONObject():New()
Local oResult

oJSON[#'data'] := { }
oJSON[#'sub' ] := 12.4

aAdd( oJSON[#'data'], JSONObject():New() )

oJSON[#'data'][ 1 ][#'name'] := 'Marcelo'
oJSON[#'data'][ 1 ][#'age']  := 19
// {"data":[{"name":"Marcelo","age":19}],"sub":12.4}

oResult := JSON():New( oJSON )
Return oResult:Stringify()
```

#### Ler e escrever dados por JSON
```xbase
Function JSONFromST1
  Local aResults := { }
  Local oObj

  dbSelectArea( 'ST1' )
  dbGoTop()

  While !Eof()
    oObj := JSONObject():New()
    oObj[#'codigo'] := ST1->T1_CODFUNC
    oObj[#'nome']   := ST1->T1_NOME
    aAdd( aResults, oObj )
    dbSkip()
  End

  dbCloseArea()

  Return JSON():New( aResults ):Stringify()

Function JSONToST1( cJSON )
  Local oParser := JSON():New( cJSON )
  Local oJSON

  oParser := oParser:Parse()

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

## Mantenedores

Esse projeto é mantido e desenvolvido pela [NG Informática](http://ngi.com.br) ─ TOTVS Software Partner

<div align="center" style="width: 100%; height: 100px; vertical-align:middle;">
   <div>
      <img src="https://avatars1.githubusercontent.com/u/21263692?v=3&s=200" />
   </div>
   <div>
      <img src="http://www.escriba.com.br/wp-content/uploads/2014/10/totvs.png" width="100" />
   </div>
</div>

## Log de alterações

Elaborado por Marcelo Camargo em 09/06/2016
