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
#include 'json.ch'
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

#define TOKEN_TYPE   1
#define TOKEN_VALUE  2
#define TOKEN_LINE   3
#define TOKEN_COLUMN 4

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
#xtranslate @Match <cToken> => If Self:nIndex <= Len( Self:xStream ) .And. Self:xStream\[ Self:nIndex, 1 \] == <cToken> ;;
            Self:xBuffer := Self:xStream\[ Self:nIndex \]    ;;
            Self:nIndex++                                    ;;
    Else                                                     ;;
        Self:lHasError := .T.                                ;;
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
        Upper( GetClassName( <xObj> ) ) == 'JSONSYNTAXERROR'
#endif

#ifndef CRLF
    #define CRLF Chr( 13 ) + Chr( 10 )
#endif

/**
 * Returns the content of a file as string
 * @param cFileName Character
 * @return Character
 */
Static Function GetFileContents( cFileName )
    Local nHandler := FOpen( cFileName, FO_READWRITE + FO_SHARED )
    Local nSize    := 0
    Local xBuffer  := ''

    If nHandler == -1
        Return Nil
    EndIf

    nSize := FSeek( nHandler, 0, FS_END )
    FSeek( nHandler, 0 )
    #ifdef __HARBOUR__
        FRead( nHandler, @xBuffer, nSize )
    #else
        FRead( nHandler, xBuffer, nSize )
    #endif

    FClose( nHandler )
    Return xBuffer

/**
 * Representation of a syntactic error in JSON.
 * @class JSONSyntaxError
 */
Class JSONSyntaxError
    Data cMessage
    Data nLine
    Data nColumn

    Method New( cMessage, nLine, nColumn ) Constructor
    Method Error()
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
 * @method Error
 * @return Character
 */
Method Error() Class JSONSyntaxError
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
    Data aKeys
    Data aValues

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
    ::aKeys   := { }
    ::aValues := { }
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
    For nI := 1 To nSize
        If ::aKeys[ nI ] == cKey
            ::aValues[ nI ] := xValue
            Return
        EndIf
    Next nI

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

    For nI := 1 To nSize
        If ::aKeys[ nI ] == cKey
            Return ::aValues[ nI ]
        EndIf
    Next nI

    Return Nil

/**
 * The lexer returns a stream of tokens or a syntax error
 *
 * @class JSONLexer
 */
Class JSONLexer
    Data aCharList
    Data aTokens
    Data cError
    Data nPosition
    Data nSourceSize
    Data nLine
    Data nColumn

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
    ::aTokens     := { }
    ::cError      := ''
    ::nSourceSize := Len( ::aCharList )
    ::nPosition   := 1
    ::nLine       := 1
    ::nColumn     := 1
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
    Local xHelper
    Local nI

    // When it is a valid process, we get an array
    If ValType( aLex ) == 'A'
        For nI := 1 To Len( aLex )
            Do Case
                Case aLex[ nI, 1 ] == T_STRING
                    xHelper := aLex[ nI, 2 ]
                    xHelper := StrTran( xHelper, '\', '\\"' )
                    xHelper := StrTran( xHelper, '"', '\"' )

                    cOut += '"' + xHelper + '"'

                Case aLex[ nI, 1 ] == T_NUMBER
                    cOut += AllTrim( Str( aLex[ nI, 2 ] ) )

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
        Return aLex
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

    // Note: AdvPL and Harbour don't support e-notation. The value is, therefore,
    // in this moment, ignored
    @Add_Token { T_NUMBER, Val( xBuffer ), ::nLine, nCursor }
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

    // Process buffer after
    xBuffer := StrTran( xBuffer, '\t', Chr( 9 ) )
    xBuffer := StrTran( xBuffer, '\b', Chr( 8 ) )
    xBuffer := StrTran( xBuffer, '\r', Chr( 13 ) )
    xBuffer := StrTran( xBuffer, '\n', Chr( 10 ) )
    xBuffer := StrTran( xBuffer, '\f', Chr( 12 ) )
    xBuffer := StrTran( xBuffer, '\/', '/' )
    xBuffer := StrTran( xBuffer, '\"', '"')
    // Currently, we are ignoring unicode characters such as \u0000 because
    // I didn't find support neither in AdvPL nor Harbour

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
    Data xStream
    Data nIndex
    Data lHasError
    Data xAST
    Data xBuffer

    Method New( xStream ) Constructor
    Method IsJSON()
    Method Object()
    Method Parse()

    Method _Object()
    Method _Array()
    Method _Value()
EndClass

/**
 * Instance for JSONParser
 * @class JSONParser
 * @method New
 * @param xStream Array | Object the token stream or a syntactic error
 * @return JSONParser
 */
Method New( xStream ) Class JSONParser
    ::xStream   := xStream
    ::nIndex    := 1
    ::lHasError := .F.
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
 * @return JSONObject | Array
 */
Method Object() Class JSONParser
    If ::IsJSON()
        Return ::xAST
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

    // Object
    If @Current_In_Parser[ 1 ] == T_OPEN_BRACE
        ::xAST := ::_Object()
        If @Has_Syntax_Error ::xAST
            Return ::xAST
        EndIf

    // Array
    ElseIf @Current_In_Parser[ 1 ] == T_OPEN_BRACKET
        ::xAST := ::_Array()
        If @Has_Syntax_Error ::xAST
            Return ::xAST
        EndIf

    // Syntax error
    Else
        @Match T_OPEN_BRACE + ' OR ' + T_OPEN_BRACKET
    EndIf

    Return Self

/**
 * Object production for the parser
 * @class JSONParser
 * @method _Object
 * @return JSONObject
 */
Method _Object() Class JSONParser
    Local oObject := JSONObject():New()
    Local cKey
    Local xValue

    @Match T_OPEN_BRACE

    If @Current_In_Parser[ 1 ] == T_STRING
        @Match T_STRING
        cKey := ::xBuffer[ 2 ]

        @Match T_COLON
        xValue := ::_Value()

        If @Has_Syntax_Error xValue
            Return xValue
        EndIf

        oObject:Set( cKey, xValue )

        While @Current_In_Parser[ 1 ] == T_COMMA
            @Consume
            @Match T_STRING
            cKey := ::xBuffer[ 2 ]
            @Match T_COLON
            xValue := ::_Value()

            If @Has_Syntax_Error xValue
                Return xValue
            EndIf

            oObject:Set( cKey, xValue )
        End

    EndIf

    @Match T_CLOSE_BRACE

    Return oObject

/**
 * Array production for the parser
 * @class JSONParser
 * @method _Array
 * @return Array
 */
Method _Array() Class JSONParser
    Local aResults := { }
    Local xValue

    @Match T_OPEN_BRACKET

    If @Current_In_Parser[ 1 ] <> T_CLOSE_BRACKET
        xValue := ::_Value()

        If @Has_Syntax_Error xValue
            Return xValue
        EndIf

        aAdd( aResults, xValue )

        While @Current_In_Parser[ 1 ] == T_COMMA
            @Consume

            xValue := ::_Value()

            If @Has_Syntax_Error xValue
                Return xValue
            EndIf

            aAdd( aResults, xValue )
        End

    EndIf

    @Match T_CLOSE_BRACKET
    Return aResults

/**
 * Value production for the parser
 * @class JSONParser
 * @method _Value
 * @return Character | Logic | Number
 */
Method _Value() Class JSONParser

    Do Case
        Case @Current_In_Parser[ 1 ] == T_NUMBER
            @Match T_NUMBER
            Return ::xBuffer[ 2 ]

        Case @Current_In_Parser[ 1 ] == T_STRING
            @Match T_STRING
            Return ::xBuffer[ 2 ]

        Case @Current_In_Parser[ 1 ] == T_TRUE
            @Consume
            Return .T.

        Case @Current_In_Parser[ 1 ] == T_FALSE
            @Consume
            Return .F.

        Case @Current_In_Parser[ 1 ] == T_NULL
            @Consume
            Return Nil

        Case @Current_In_Parser[ 1 ] == T_OPEN_BRACE
            JVAL = ::_Object()
            Return JVAL

        Case @Current_In_Parser[ 1 ] == T_OPEN_BRACKET
            JVAL := ::_Array()
            Return JVAL

    EndCase

    @Match 'value (string, boolean, object, number or array)'

    Return Nil

/**
 * The class that will use the JSONLexer and the JSONParser to be exposed
 * to the developer level.
 *
 * @class JSON
 */
Class JSON
    Data xData

    Method New( xData ) Constructor
    Method Parse()
    Method Stringify()
    Method Minify()
    Method File()
EndClass

/**
 * Creates a JSON object
 * @class JSON
 * @method New
 * @param Any
 * @return JSON
 */
Method New( xData ) Class JSON
    ::xData := xData
    Return Self

/**
 * Parses a JSON
 * @class JSON
 * @method New
 * @return JSONObject | Array
 */
Method Parse() Class JSON
    Local aLexer  := JSONLexer():New( ::xData )
    Local xResult

    aLexer := aLexer:GetTokens()
    xResult := JSONParser():New( aLexer )
    xResult := xResult:Parse()
    Return xResult

/**
 * Converts a JSON object o a string
 * @class JSON
 * @method Stringify
 * @return Character
 */
Method Stringify( lOptimize ) Class JSON
    Local cResult
    If lOptimize
        cResult := OptToString( ::xData )
    Else
        cResult := ToString( ::xData )
    EndIf
    Return cResult

Static Function OptToString( xItem )
    Local oResult
    Local cType   := ValType( xItem )
    Local xHelper := ''
    Local nI

    Do Case
        Case cType == 'U'
            Return 'null'

        Case cType == 'N'
            Return AllTrim( Str( xItem ) )

        Case cType == 'C'
            xHelper := StrTran( xItem, '\', '\\' )
            xHelper := StrTran( xHelper, '"', '\"')
            Return '"' + xHelper + '"'

        Case cType == 'L'
            Return IIf( xItem, 'true', 'false' )

        Case cType == 'A'
            oResult := StringBuilder():New( '[' )

            For nI := 1 To Len( xItem )
                oResult:Append( OptToString( xItem[ nI ] ) )

                If nI < Len( xItem )
                    oResult:Append( ',' )
                EndIf
            Next nI

            oResult:Append( ']' )
            xHelper := oResult:Read()
            oResult:Dispose()
            Return xHelper

        Case cType == 'O'
            oResult := StringBuilder():New( '{' )

            For nI := 1 To Len( xItem:aKeys )
                oResult:Append( ToString( xItem:aKeys[ nI ] ) )
                oResult:Append( ':' )
                oResult:Append( ToString( xItem:aValues[ nI ] ) )

                If nI < Len( xItem:aKeys )
                    oResult:Append( ',' )
                EndIf
            Next nI

            oResult:Append( '}' )
            xHelper := oResult:Read()
            oResult:Dispose()
            Return xHelper

    EndCase
    Return Nil

Static Function ToString( xItem )
    Local cResult := ''
    Local cType   := ValType( xItem )
    Local xHelper := ''
    Local nI

    Do Case
        Case cType == 'U'
            cResult += 'null'

        Case cType == 'N'
            cResult += Str( xItem )

        Case cType == 'C'
            xHelper := StrTran( xItem, '\', '\\' )
            xHelper := StrTran( xHelper, '"', '\"')
            cResult += '"' + xHelper + '"'

        Case cType == 'L'
            cResult := IIf( xItem, 'true', 'false' )

        Case cType == 'A'
            cResult += '['

            For nI := 1 To Len( xItem )
                cResult += ToString( xItem[ nI ] )

                If nI < Len( xItem )
                    cResult += ','
                EndIf
            Next nI

            cResult += ']'

        Case cType == 'O'
            cResult += '{'

            For nI := 1 To Len( xItem:aKeys )
                cResult += ToString( xItem:aKeys[ nI ] )
                cResult += ':'
                cResult += ToString( xItem:aValues[ nI ] )

                If nI < Len( xItem:aKeys )
                    cResult += ','
                EndIf
            Next nI

            cResult += '}'

    EndCase

    Return AllTrim( cResult )

/**
 * Minifies a JSON string
 * @class JSON
 * @method Minify
 * @return Character
 */
Method Minify() Class JSON
    Local oLexer := JSONLexer():New( ::xData )
    Return oLexer:Minify()

/**
 * Reads a JSON file and parses it
 * @class JSON
 * @method File
 * @return JSONObject
 */
Method File() Class JSON
    ::xData := GetFileContents( ::xData )
    Return Self

/**
 * Exposed function to parse JSON
 * @param cJSON Character
 * @param @oJSON Reference<Object>
 * @return boolean
 */
User Function ParseJSON( cJSON, oJSON )
    Local oParser := JSON():New( cJSON )
    oParser := oParser:Parse()

    If oParser:IsJSON()
        @oJSON := oParser:Object()
        Return .T.
    EndIf

    @oJSON := oParser:Error()
    Return .F.
