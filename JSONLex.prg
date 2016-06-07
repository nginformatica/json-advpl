#include 'fileio.ch'
#ifdef __HARBOUR__
  #include 'hbclass.ch'
#else
  #include 'protheus.ch'
#endif

Class JSONObject
  Data aKeys   Init { }
  Data aValues Init { }

  Method New() Constructor
  Method Set( cKey, xValue )
  Method Get( cKey )
EndClass

Method New() Class JSONObject
  Return Self

Method Set( cKey, xValue ) Class JSONObject
  aAdd( ::aKeys, cKey )
  aAdd( ::aValues, xValue )
  Return

Method Get( cKey ) Class JSONObject
  Local nSize := Len( ::aKeys )
  Local nI

  If nSize <> 0
    For nI := 1 To nSize
      If ::aKeys[ nI ] == cKey
        Return ::aValues[ nI ]
      EndIf
    Next nI
  End

  Return Nil


// Define tokens

#define T_OPEN_BRACE    "T_OPEN_BRACE"
#define T_CLOSE_BRACE   "T_CLOSE_BRACE"
#define T_COMMA         "T_COMMA"
#define T_COLON         "T_COLON"
#define T_OPEN_BRACKET  "T_OPEN_BRACKET"
#define T_CLOSE_BRACKET "T_CLOSE_BRACKET"
#define T_TRUE          "T_TRUE"
#define T_FALSE         "T_FALSE"
#define T_NULL          "T_NULL"
#define T_NUMBER        "T_NUMBER"
#define T_STRING        "T_STRING"
#define T_ERROR         "T_ERROR"

#xtranslate @Add_Token <xTok> => aAdd( aTokens, <xTok> )
#xtranslate @Lexer_Error <cMessage> => Return { { T_ERROR, <cMessage> } }
#xtranslate @Parse_Error <cMessage> => Return { { <cMessage> } }
#xtranslate @Match { <w> } => IsMatch( <w>, aCharList, nPosition, nSourceSize )
#xtranslate @Not_Eof => ( nPosition <= nSourceSize )
#xtranslate @Increase_Position => nPosition++; nColumn++
#xtranslate \[ \# <cKey> \] => :Get( <cKey> )
#xtranslate \[ \# <cKey> \] := <cValue> => :Set( <cKey>, <cValue> )

Static Function StrToList( cStr )
  Local aList := { }
  Local nI
  Local xBuffer

  For nI := 1 To Len( cStr )
    aAdd( aList, SubStr( cStr, nI, 1 ) )
  Next nI

  Return aList

Function JSONLex( cSource )
  Local aTokens     := { }
  Local aCharList   := StrToList( cSource )
  Local nPosition   := 1
  Local nSourceSize := Len( aCharList )
  Local nLine       := 1
  Local nColumn     := 1
  Local nHelper
  Local nCursor

  If nSourceSize == 0
    @Lexer_Error 'No source provided'
  EndIf

  While @Not_Eof

    Do Case
      Case aCharList[ nPosition ] == '{'
        @Add_Token { T_OPEN_BRACE, Nil, nLine, nColumn }
        @Increase_Position

      Case aCharList[ nPosition ] == '}'
        @Add_Token { T_CLOSE_BRACE, Nil, nLine, nColumn }
        @Increase_Position

      Case aCharList[ nPosition ] == '['
        @Add_Token { T_OPEN_BRACKET, Nil, nLine, nColumn }
        @Increase_Position

      Case aCharList[ nPosition ] == ']'
        @Add_Token { T_CLOSE_BRACKET, Nil, nLine, nColumn }
        @Increase_Position

      Case aCharList[ nPosition ] == ','
        @Add_Token { T_COMMA, Nil, nLine, nColumn }
        @Increase_Position

      Case aCharList[ nPosition ] == ':'
        @Add_Token { T_COLON, Nil, nLine, nColumn }
        @Increase_Position

      Otherwise
        // Keyword
        If IsAlpha( aCharList[ nPosition ] )
          xBuffer := ''

          While @Not_Eof .And. ( IsAlpha( aCharList[ nPosition ] ) .Or. IsDigit( aCharList[ nPosition ] ) )
            xBuffer += aCharList[ nPosition ]
            @Increase_Position
          End

          Do Case
            Case xBuffer == 'true'
              @Add_Token { T_TRUE, Nil, nLine, nColumn }

            Case xBuffer == 'false'
              @Add_Token { T_FALSE, Nil, nLine, nColumn }

            Case xBuffer == 'null'
              @Add_Token { T_NULL, Nil, nLine, nColumn }

            Otherwise
              @Lexer_Error 'Unexpected identifier: ' + xBuffer
          EndCase

          Loop
        EndIf

        // Number
        If aCharList[ nPosition ] == '-' .Or. IsDigit( aCharList[ nPosition ] )
          xBuffer := ''
          nCursor := nPosition

          If aCharList[ nPosition ] == '-'
            xBuffer += '-'
            @Increase_Position
          EndIf

          // When zero
          If aCharList[ nPosition ] == '0'
            xBuffer += '0'
            @Increase_Position

            // When we have more numbers after zero
            If @Not_Eof .And. IsDigit( aCharList[ nPosition ] )
              @Lexer_Error 'Invalid number'
            EndIf

          ElseIf IsDigit( aCharList[ nPosition ] )
            // Consume while is digit and not EOF

            While @Not_Eof .And. IsDigit( aCharList[ nPosition ] )
              xBuffer += aCharList[ nPosition ]
              @Increase_Position
            End
          Else
            @Lexer_Error 'Expecting number after minus sign'
          EndIf

          // Optional floating point
          If @Not_Eof .And. aCharList[ nPosition ] == '.'
            xBuffer += '.'
            @Increase_Position

            While @Not_Eof .And. IsDigit( aCharList[ nPosition ] )
              xBuffer += aCharList[ nPosition ]
              @Increase_Position
            End
          EndIf

          // Optional [eE][\+\-]
          If @Not_Eof .And. aCharList[ nPosition ] $ 'Ee'
            xBuffer += aCharList[ nPosition ]
            @Increase_Position

            // Optional plus or minus sign
            If @Not_Eof .And. aCharList [ nPosition ] $ '+-'
              xBuffer += aCharList[ nPosition ]
              @Increase_Position
            EndIf

            // Rest of the digits
            While @Not_Eof .And. IsDigit( aCharList[ nPosition ] )
              xBuffer += aCharList[ nPosition ]
              @Increase_Position
            End
          EndIf

          @Add_Token { T_NUMBER, xBuffer, nLine, nCursor }
          Loop
        EndIf

        // Whitespace
        xBuffer := Asc( aCharList[ nPosition ] )
        If xBuffer == 32 .Or. xBuffer == 9
          @Increase_Position
          Loop
        // 13 + 10
        ElseIf xBuffer == 13
          @Increase_Position
          nColumn := 1

          If @Not_Eof .And. Asc( aCharList[ nPosition ] ) == 10
            nPosition++
          EndIf

          nLine++
          Loop
        ElseIf xBuffer == 10
          @Increase_Position
          // On newline, reset column and increase line
          nColumn := 1
          nLine++
          Loop
        EndIf

        // String
        If aCharList[ nPosition ] == '"'
          xBuffer := ''
          nCursor := nPosition

          @Increase_Position

          // Close string when reach {"}
          While @Not_Eof .And. aCharList[ nPosition ] <> '"'
            If aCharList[ nPosition ] == '\'
              xBuffer += '\'
              @Increase_Position

              If aCharList[ nPosition ] $ '"\/bfnrt'
                xBuffer += aCharList[ nPosition ]
                @Increase_Position
              ElseIf aCharList[ nPosition ] == 'u'
                xBuffer += 'u'
                @Increase_Position
                nHelper := 1

                While nHelper <= 4
                  If .Not. @Not_Eof
                    @Lexer_Error 'Expecting 4 hexadecimal digits. Found EOF'
                  EndIf

                  If IsDigit( aCharList[ nPosition ] ) .Or. aCharList[ nPosition ] $ 'ABCDEFabcdef'
                    xBuffer += aCharList[ nPosition ]
                    @Increase_Position
                    nHelper++
                  Else
                    @Lexer_Error 'Expecting an hexadecimal digit. Found ' + aCharList[ nPosition ]
                  EndIf
                End
              Else
                @Lexer_Error 'Unrecognized escaped character'
              EndIf

            Else
              xBuffer += aCharList[ nPosition ]
              @Increase_Position
            EndIf
          End

          If .Not. @Not_Eof .Or. aCharList[ nPosition ] <> '"'
            @Lexer_Error 'Expecting string terminator'
          EndIf

          @Increase_Position
          @Add_Token { T_STRING, xBuffer, nLine, nCursor }
          Loop
        EndIf

        @Lexer_Error 'No matches for [' + aCharList[ nPosition ] + ']'
    EndCase
  End

  Return aTokens

Function JSONMinify( cSource )
  Local aLex := JSONLex( cSource )
  Local cOut := ''
  Local nI

  If .Not. ( Len( aLex ) == 1 .And. aLex[ 1, 1 ] == T_ERROR )
    For nI := 1 To Len( aLex )
      Do Case
        Case aLex[ nI, 1 ] == T_STRING
          cOut += '"' + aLex[ nI, 2 ] + '"'

        Case aLex[ nI, 1 ] == T_NUMBER
          cOut += aLex[ nI, 2 ]

        Case aLex[ nI, 1 ] == T_TRUE
          cOut += 'true'

        Case aLex[ nI, 1 ] == T_FALSE
          cOut += 'false'

        Case aLex[ nI, 1 ] == T_NULL
          cOut += 'null'

        Case aLex[ nI, 1 ] == T_OPEN_BRACE
          cOut += '{'

        Case aLex[ nI, 1 ] == T_CLOSE_BRACE
          cOut += '}'

        Case aLex[ nI, 1 ] == T_OPEN_BRACKET
          cOut += '['

        Case aLex[ nI, 1 ] == T_CLOSE_BRACKET
          cOut += ']'

        Case aLex[ nI, 1 ] == T_COLON
          cOut += ':'

        Case aLex[ nI, 1 ] == T_COMMA
          cOut += ','

      EndCase
    Next nI
  Else
    Return { aLex[ 1, 2 ] }
  EndIf

  Return cOut

Function Main
  Local oData := JSONObject():New()
  Local oSub  := JSONObject():New()

  oSub[#'sub'] := 'java'
  oData[#'key'] := oSub

  oData[#'key'][#'sub'] := 1

  OutStd( oData[#'key'][#'sub'] )

  Return

Function TestMinify
  Local nHandler  := fOpen( './json/main.json', FO_READWRITE + FO_SHARED )
  Local nSize     := Directory( './json/main.json' )[ 1, 2 ]
  Local xBuffer   := Space( nSize )
  Local cMinified

  fRead( nHandler, @xBuffer, nSize )
  cMinified := JSONMinify( xBuffer )
  OutStd( cMinified )
  Return
