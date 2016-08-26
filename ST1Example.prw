#include 'json.ch'
#include 'protheus.ch'

// Read from ST1
Function JSONFromST1
  Local aResults := { }
  Local nI   := 1
  Local oResult

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

  oResult := JSON():New( aResults )

  Return oResult:Stringify()

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
