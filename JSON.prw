/**
 * TODO List:
 * - The parser should allow opening a file for parsing
 * - We must have a class named JSON to expose the operations for the user
 * - We need to allow converting an object to a JSON also
 */

/**
 * JSON parser (according to RFC 4627)
 *
 * This is a full parser compatible with Harbour and AdvPL.
 * It includes a fully functional lexer, a parser and a code generator.
 *
 * @author Marcelo Camargo <marcelo.camargo@ngi.com.br>
 *                         <marcelocamargo@linuxmail.org>
 * @since 2016-06-07
 * @copyright 2016 - NG Informática - TOTVS Software Partner
 */
#include 'fileio.ch'
#ifdef __HARBOUR__
   #include 'hbclass.ch'
#else
   #include 'protheus.ch'
#endif

// Language tokens
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

#define TOKEN_TYPE   1
#define TOKEN_VALUE  2
#define TOKEN_LINE   3
#define TOKEN_COLUMN 4

// Syntactic additions for associative arrays
#xtranslate \[ \# <cKey> \] => :Get( <cKey> )
#xtranslate \[ \# <cKey> \] := <xValue> => :Set( <cKey>, <xValue> )

// Syntactic additions for the lexer
#xtranslate @Lexer_Error Line <line> Column <column> => Return JSONSyntaxError():New( Self:cError, <line>, <column> )
#xtranslate @Has_Lexer_Error => !Empty( Self:cError )
#xtranslate @Add_Token <aToken> => aAdd( Self:aTokens, <aToken> )
#xtranslate @Not_Eof => ( Self:nPosition <= Self:nSourceSize )
#xtranslate @Current_In_Lexer => Self:aCharList\[ Self:nPosition \]
#xtranslate @Increase_Position => Self:nPosition++; Self:nColumn++

// Syntactic additions for the parser
#xtranslate @Current_In_Parser => Self:xStream\[ Self:nIndex \]
#xtranslate @Consume => Self:nIndex++
#xtranslate @Match <cToken> => ;;
   If Self:nIndex <= Len( Self:xStream ) .And. Self:xStream\[ Self:nIndex, 1 \] == <cToken>    ;;
         Self:xBuffer := Self:xStream\[ Self:nIndex \]    ;;
         Self:nIndex++                                    ;;
   Else                                                   ;;
      Self:lHasError := .T.                               ;;
      Return JSONSyntaxError():New( 'Expecting ' + <cToken> + '. Got ' + IIf( Self:nIndex <= Len( Self:xStream ),  Self:xStream\[ Self:nIndex \]\[ 1 \], 'EOF' ), ;
                                    IIf( Self:nIndex <= Len( Self:xStream ), Self:xStream\[ Self:nIndex \]\[ 3 \], Self:xStream\[ Self:nIndex - 1 \]\[ 3 \]),     ;
                                    IIf( Self:nIndex <= Len( Self:xStream ), Self:xStream\[ Self:nIndex \]\[ 4 \], Self:xStream\[ Self:nIndex - 1 \]\[ 3 \]) )   ;;
   EndIf



// Tell when we got syntax error in a structure. It is different from Harbour
// to AdvPL
#ifdef __HARBOUR__
   #xtranslate @Has_Syntax_Error <xObj> => ValType( <xObj> ) == 'O' .And. ;
      __objHasData( <xObj>, 'cMessage' )
#else
   #xtranslate @Has_Syntax_Error <xObj> => ValType( <xObj> ) == 'O' .And. ;
      Upper( GetClassName( <xObj> ) ) == 'JSONSyntaxError'
#endif

#ifndef CRLF
   #define CRLF Chr( 13 ) + Chr( 10 )
#endif

/**
 * Representation of a syntactic error in JSON.
 * @class JSONSyntaxError
 */
Class JSONSyntaxError
   Data cMessage Init ''
   Data nLine    Init 1
   Data nColumn  Init 1

   Method New( cMessage, nLine, nColumn ) Constructor
   Method Format()
   Method IsJSON()
EndClass

/**
 * Instance for JSONSyntaxError.
 * @class JSONSyntaxError
 * @method New
 * @return JSONSyntaxError
 */
Method New( cMessage, nLine, nColumn ) Class JSONSyntaxError
   ::cMessage := cMessage
   ::nLine    := nLine
   ::nColumn  := nColumn
   Return Self

/**
 * Formats a syntax error message.
 * @class JSONSyntaxError
 * @method Format
 * @return Character
 */
Method Format() Class JSONSyntaxError
   Local cStr := '*** JSON syntax error! '
   cStr += ::cMessage + CRLF
   cStr += '    Line:   ' + Str( ::nLine ) + CRLF
   cStr += '    Column: ' + Str( ::nColumn ) + CRLF
   Return cStr

/**
 * Specifies that a JSONSyntaxError is not a JSON
 * @class JSONSyntaxError
 * @method IsJSON
 * @return Logic
 */
Method IsJSON() Class JSONSyntaxError
   Return .F.

/**
 * Representation of an associative array. We also extend the syntax to allow
 * using oValue[#'first_prop'][#'sub_prop']. It works like any other variable.
 * @class JSONObject
 */
Class JSONObject
   Data aKeys   Init { }
   Data aValues Init { }

   Method New() Constructor
   Method Set( cKey, xValue )
   Method Get( cKey )
EndClass

/**
 * Instance for JSONObject
 * @class JSONObject
 * @method New
 * @return JSONObject
 */
Method New() Class JSONObject
   Return Self

/**
 * Our object is a set. This method creates or updates the entry according to
 * it's key, simulating a hashmap.
 * @class JSONObject
 * @method Set
 * @param cKey The key of the associative array
 * @param xValue The value of the associative array
 * @return Nil
 */
Method Set( cKey, xValue ) Class JSONObject
   Local nSize := Len( ::aKeys )
   Local nI

   // When the key is found, update. Otherwise, create
   If nSize <> 0
      For nI := 1 To nSize
         If ::aKeys[ nI ] == cKey
            ::aValues[ nI ] := xValue
            Return
         EndIf
      Next nI
   End

   aAdd( ::aKeys, cKey )
   aAdd( ::aValues, xValue )
   Return

/**
 * Returns the value by key. Nil when not found
 * @class JSONObject
 * @method Get
 * @param cKey The key of the associative array
 * @return Any
 */
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

/**
 * The lexer returns a stream of tokens or one single token containing { T_ERROR }
 *
 * @class JSONLexer
 */
Class JSONLexer
   Data aCharList   Init { }
   Data aTokens     Init { }
   Data cError      Init ''
   Data nPosition   Init 1
   Data nSourceSize Init 0
   Data nLine       Init 1
   Data nColumn     Init 1

   Method New( cSource ) Constructor
   Method StrToList( cStr )
   Method Minify()
   Method GetTokens()
   Method Keyword()
   Method Number()
   Method WhiteSpace()
   Method String()
EndClass

/**
 * Instance for JSONLexer
 * @class JSONLexer
 * @method New
 * @return JSONLexer
 */
Method New( cSource ) Class JSONLexer
   ::aCharList   := ::StrToList( cSource )
   ::nSourceSize := Len( ::aCharList )
   Return Self

/**
 * Converts a string to a char list
 * @class JSONLexer
 * @method StrToList
 * @param cStr The string to be converted
 * @return Array
 */
Method StrToList( cStr ) Class JSONLexer
   Local aList := { }
   Local nI
   Local xBuffer
   For nI := 1 To Len( cStr )
      aAdd( aList, SubStr( cStr, nI, 1 ) )
   Next nI

   Return aList

/**
 * Minifies a JSON string
 * @class JSONLexer
 * @method Minify
 * @return Character
 */
Method Minify() Class JSONLexer
   Local aLex := ::GetTokens()
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

/**
 * Returns the token stream based on lexical analysis
 * @class JSONLexer
 * @method GetTokens
 * @return Array
 */
Method GetTokens() Class JSONLexer
   ::aTokens := { }

   If ::nSourceSize == 0
      ::cError := 'No source provided'
      @Lexer_Error Line 1 Column 1
   EndIf

   While @Not_Eof
      Do Case
         Case @Current_In_Lexer == '{'
            @Add_Token { T_OPEN_BRACE, Nil, ::nLine, ::nColumn }
            @Increase_Position

         Case @Current_In_Lexer == '}'
            @Add_Token { T_CLOSE_BRACE, Nil, ::nLine, ::nColumn }
            @Increase_Position

         Case @Current_In_Lexer == '['
            @Add_Token { T_OPEN_BRACKET, Nil, ::nLine, ::nColumn }
            @Increase_Position

         Case @Current_In_Lexer == ']'
            @Add_Token { T_CLOSE_BRACKET, Nil, ::nLine, ::nColumn }
            @Increase_Position

         Case @Current_In_Lexer == ','
            @Add_Token { T_COMMA, Nil, ::nLine, ::nColumn }
            @Increase_Position

         Case @Current_In_Lexer == ':'
            @Add_Token { T_COLON, Nil, ::nLine, ::nColumn }
            @Increase_Position

         Otherwise
            // Keyword
            If ::Keyword()
               Loop
            ElseIf @Has_Lexer_Error
               @Lexer_Error Line ::nLine Column ::nColumn
            EndIf

            // Number
            If ::Number()
               Loop
            ElseIf @Has_Lexer_Error
               @Lexer_Error Line ::nLine Column ::nColumn
            EndIf

            // WhiteSpace
            If ::WhiteSpace()
               Loop
            EndIf

            If ::String()
               Loop
            ElseIf @Has_Lexer_Error
               @Lexer_Error Line ::nLine Column ::nColumn
            EndIf

            ::cError := 'No matches for [' + @Current_In_Lexer + ']'
            @Lexer_Error Line ::nLine Column ::nColumn
      EndCase
   End

   Return ::aTokens

/**
 * Finds a keyword
 * @class JSONLexer
 * @method Keyword
 * @return Logic
 */
Method Keyword() Class JSONLexer
   Local xBuffer       := ''
   Local nCursorLine   := ::nLine
   Local nCursorColumn := ::nColumn

   If .Not. IsAlpha( @Current_In_Lexer )
      Return .F.
   EndIf

   While @Not_Eof .And. ( IsAlpha( @Current_In_Lexer ) .Or. IsDigit( @Current_In_Lexer ) )
      xBuffer += @Current_In_Lexer
      @Increase_Position
   End

   Do Case
      Case xBuffer == 'true'
         @Add_Token { T_TRUE, Nil, ::nLine, ::nColumn }
         Return .T.

      Case xBuffer == 'false'
         @Add_Token { T_FALSE, Nil, ::nLine, ::nColumn }
         Return .T.

      Case xBuffer == 'null'
         @Add_Token { T_NULL, Nil, ::nLine, ::nColumn }
         Return .T.

      Otherwise
         ::nLine   := nCursorLine
         ::nColumn := nCursorColumn
         ::cError  := 'Unexpected identifier [' + xBuffer + ']'
   EndCase

   Return .F.

/**
 * Finds a number
 * @class JSONLexer
 * @method Number
 * @return Logic
 */
Method Number() Class JSONLexer
   Local xBuffer       := ''
   Local nCursor       := ::nPosition
   Local nCursorLine   := ::nLine
   Local nCursorColumn := ::nColumn

   If .Not. ( @Current_In_Lexer == '-' .Or. IsDigit( @Current_In_Lexer ) )
      Return .F.
   EndIf

   If @Current_In_Lexer == '-'
      xBuffer += '-'
      @Increase_Position
   EndIf

   // When zero
   If @Current_In_Lexer == '0'
      xBuffer += '0'
      @Increase_Position

      // When we have more numbers after zero
      If @Not_Eof .And. IsDigit( @Current_In_Lexer )
         ::nLine   := nCursorLine
         ::nColumn := nCursorColumn
         ::cError  := 'Invalid number'
         Return .F.
      EndIf

   ElseIf IsDigit( @Current_In_Lexer )

      // Consume while is digit and not EOF
      While @Not_Eof .And. IsDigit( @Current_In_Lexer )
         xBuffer += @Current_In_Lexer
         @Increase_Position
      End

   Else
      ::nLine   := nCursorLine
      ::nColumn := nCursorColumn
      ::cError := 'Expecting number after minus sign'
      Return .F.
   EndIf

   // Optional floating point
   If @Not_Eof .And. @Current_In_Lexer == '.'
      xBuffer += '.'
      @Increase_Position
      While @Not_Eof .And. IsDigit( @Current_In_Lexer )
         xBuffer += @Current_In_Lexer
         @Increase_Position
      End
   EndIf

   // Optional [eE][\+\-]
   If @Not_Eof .And. @Current_In_Lexer $ 'Ee'
      xBuffer += @Current_In_Lexer
      @Increase_Position

      // Optional plus or minus sign
      If @Not_Eof .And. @Current_In_Lexer $ '+-'
         xBuffer += @Current_In_Lexer
         @Increase_Position
      EndIf

      // Rest of the digits
      While @Not_Eof .And. IsDigit( @Current_In_Lexer )
         xBuffer += @Current_In_Lexer
         @Increase_Position
      End

   EndIf

   @Add_Token { T_NUMBER, xBuffer, ::nLine, nCursor }
   Return .T.

/**
 * Consumes whitespaces and identifies lines and columns
 * @class JSONLexer
 * @method WhiteSpace
 * @return Logic
 */
Method WhiteSpace() Class JSONLexer
   Local xBuffer := Asc( @Current_In_Lexer )

   // Whitespace or tab
   If xBuffer == 32 .Or. xBuffer == 9
      @Increase_Position
      Return .T.

   // CR, LF or CR + LF
   ElseIf xBuffer == 13
      @Increase_Position
      ::nColumn := 1

      If @Not_Eof .And. Asc( @Current_In_Lexer ) == 10
         ::nPosition++
      EndIf

      ::nLine++
      Return .T.

   ElseIf xBuffer == 10
      @Increase_Position
      ::nColumn := 1
      ::nLine++
      Return .T.
   EndIf

   Return .F.

/**
 * Parses a string
 * @class JSONLexer
 * @method String
 * @return Logic
 */
Method String() Class JSONLexer
   Local xBuffer := ''
   Local nCursor := ::nPosition
   Local nHelper

   If .Not. ( @Current_In_Lexer == '"' )
      Return .F.
   EndIf

   @Increase_Position

   // Close string when reach {"}
   While @Not_Eof .And. @Current_In_Lexer <> '"'
      If @Current_In_Lexer == '\'
         xBuffer += '\'
         @Increase_Position

         If @Current_In_Lexer $ '"\/bfnrt'
            xBuffer += @Current_In_Lexer
            @Increase_Position
         ElseIf @Current_In_Lexer == 'u'
            xBuffer += 'u'
            @Increase_Position
            nHelper := 1

            While nHelper <= 4
               If .Not. @Not_Eof
                  ::cError := 'Expecting 4 hexadecimal digits. Found EOF'
                  Return .F.
               EndIf

               If IsDigit( @Current_In_Lexer ) .Or. @Current_In_Lexer $ 'ABCDEFabcdef'
                  xBuffer += @Current_In_Lexer
                  @Increase_Position
                  nHelper++
               Else
                  ::cError := 'Expecting an hexadecimal digit. Found ' + @Current_In_Lexer
                  Return .F.
               EndIf
            End
         Else
            ::cError := 'Unrecognized escaped character'
            Return .F.
         EndIf

      Else
         xBuffer += @Current_In_Lexer
         @Increase_Position
      EndIf
   End

   If .Not. @Not_Eof .Or. @Current_In_Lexer <> '"'
      ::cError := 'Expecting string terminator'
      Return .F.
   EndIf

   @Increase_Position
   @Add_Token { T_STRING, xBuffer, ::nLine, nCursor }
   Return .T.

/**
 * The parser is feed by the lexer and generates an abstract object
 * representation of the JSON.
 *
 * @class JSONParser
 */
Class JSONParser
   Data xStream   Init { }
   Data nIndex    Init 1
   Data lHasError Init .F.
   Data oAST
   Data xBuffer

   Method New( xStream ) Constructor
   Method IsJSON()
   Method Object()
   Method Parse()
EndClass

/**
 * Instance for JSONParser
 * @class JSONParser
 * @method New
 * @param xStream Array | Object the token stream or a syntactic error
 * @return JSONParser
 */
Method New( xStream ) Class JSONParser
   ::xStream := xStream
   Return Self

/**
 * Returns whether the JSON is valid
 * @class JSONParser
 * @method IsJSON
 * @return Logic
 */
Method IsJSON() Class JSONParser
   Return .T.

/**
 * Returns the parsed JSON as object if it is valid. Otherwise, an empty object.
 * @class JSONParser
 * @method Object
 * @return JSONObject
 */
Method Object() Class JSONParser
   If ::IsJSON()
      Return ::oAST
   EndIf
   Return JSONObject():New()

/**
 * Parses the JSON and stores its data in the object.
 * @class JSONParser
 * @method Parse
 * @return JSONParser
 */
Method Parse() Class JSONParser
   // Capture syntax error from the lexer. Our parser is also a functor,
   // being data Parser = Maybe JSONObject | JSONSyntaxError
   If @Has_Syntax_Error ::xStream
      Return ::xStream
   EndIf
   ::oAST := JSONObject():New()

   If @Current_In_Parser[ 1 ] == T_OPEN_BRACE
      @Match T_OPEN_BRACE
   ElseIf @Current_In_Parser[ 1 ] == T_OPEN_BRACKET
      @Match T_OPEN_BRACKET
   Else
      @Match T_OPEN_BRACE + ' OR ' + T_OPEN_BRACKET
   EndIf

   Return Self

/// TESTS!
Function Main
   Local xResult := JSONLexer():New( GetJSON() ):GetTokens()
   Local oResult := JSONParser():New( xResult ):Parse()

   If oResult:IsJSON()
      OutStd( "JSON Valido ")
   Else
      OutStd( oResult:Format() )
   EndIf

   Return

Function GetJSON
   Local nHandler  := fOpen( './json/main.json', FO_READWRITE + FO_SHARED )
   Local nSize     := Directory( './json/main.json' )[ 1, 2 ]
   Local xBuffer   := Space( nSize )

   fRead( nHandler, @xBuffer, nSize )
   Return xBuffer
