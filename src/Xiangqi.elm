module Xiangqi exposing
    ( Effect(..)
    , Model
    , Msg(..)
    , Piece
    , PieceKind(..)
    , Position
    , Side(..)
    , cssStyles
    , generateLegalMoves
    , inCheck
    , init
    , initialPieces
    , isGameOver
    , isSquareAttacked
    , perft
    , update
    , view
    )

import Html exposing (Html, button, div, h1, p, span, text)
import Html.Attributes exposing (attribute, class, classList, disabled, style, type_)
import Html.Events exposing (onClick)
import Json.Decode as Decode exposing (Decoder)
import VirtualDom


type Side
    = Red
    | Black


type PieceKind
    = General
    | Advisor
    | Elephant
    | Horse
    | Chariot
    | Cannon
    | Soldier


type alias Piece =
    { side : Side
    , kind : PieceKind
    }


type alias Position =
    ( Int, Int )


{-| Engine lifecycle, driven by events arriving from the JS/WebGPU engine
(see assets/engine/tinyfih.js) over a port. `EngineReady` doesn't carry the
backend name itself -- that's tracked separately in `Model.engineBackend` so
it survives the EngineReady -> EngineThinking -> EngineReady round trip of
asking for another move.
-}
type EngineStatus
    = EngineIdle
    | EngineLoading
    | EngineReady
    | EngineThinking
    | EngineFailed String


type alias EngineSuggestion =
    { from : Position
    , to : Position
    , value : Float
    }


type EngineRequestPurpose
    = AnalysisRequest
    | OpponentMoveRequest


type alias PendingRequest =
    { id : Int
    , purpose : EngineRequestPurpose
    }


type alias Model =
    { disclaimerAccepted : Bool
    , orientation : Side
    , turn : Side
    , selected : Maybe Position
    , pieces : List ( Position, Piece )
    , lastMove : Maybe ( Position, Position )
    , winner : Maybe Side
    , engineStatus : EngineStatus
    , engineBackend : Maybe String
    , suggestion : Maybe EngineSuggestion
    , agentSide : Maybe Side
    , pendingRequest : Maybe PendingRequest
    , nextRequestId : Int
    }


init : Model
init =
    { disclaimerAccepted = False
    , orientation = Red
    , turn = Red
    , selected = Nothing
    , pieces = initialPieces
    , lastMove = Nothing
    , winner = Nothing
    , engineStatus = EngineIdle
    , engineBackend = Nothing
    , suggestion = Nothing
    , agentSide = Nothing
    , pendingRequest = Nothing
    , nextRequestId = 0
    }


{-| `update` can't issue port commands itself (only a `port module` can,
and that's Main.elm) -- it reports what it'd like to happen as an `Effect`
and Main.elm turns that into the real `Cmd`.
-}
type Effect
    = NoEffect
    | LoadEngineEffect
    | RequestMoveEffect Int String (List { from : Int, to : Int })


type Msg
    = AcceptDisclaimer
    | SwitchSide
    | Select Position
    | Reset
    | RequestEngineLoad
    | RequestBestMove
    | StartAgentGame Side
    | StopAgentGame
    | EngineEventReceived Decode.Value


update : Msg -> Model -> ( Model, Effect )
update msg model =
    case msg of
        AcceptDisclaimer ->
            ( { model | disclaimerAccepted = True }, NoEffect )

        SwitchSide ->
            ( { model | orientation = opposite model.orientation, selected = Nothing }, NoEffect )

        Reset ->
            resetGame model

        Select position ->
            if canPlayerMove model then
                let
                    selectedModel =
                        selectPosition position model
                in
                if selectedModel.turn /= model.turn then
                    requestOpponentMove selectedModel

                else
                    ( selectedModel, NoEffect )

            else
                ( model, NoEffect )

        RequestEngineLoad ->
            case model.engineStatus of
                EngineIdle ->
                    ( { model | engineStatus = EngineLoading }, LoadEngineEffect )

                EngineFailed _ ->
                    ( { model | engineStatus = EngineLoading }, LoadEngineEffect )

                _ ->
                    ( model, NoEffect )

        RequestBestMove ->
            case model.agentSide of
                Nothing ->
                    beginEngineRequest AnalysisRequest model

                _ ->
                    ( model, NoEffect )

        StartAgentGame humanSide ->
            startAgentGame humanSide model

        StopAgentGame ->
            ( { model
                | agentSide = Nothing
                , selected = Nothing
                , engineStatus = readyAfterCancellation model.engineStatus
                , pendingRequest = Nothing
                , nextRequestId = model.nextRequestId + 1
              }
            , NoEffect
            )

        EngineEventReceived value ->
            handleEngineEvent value model


startAgentGame : Side -> Model -> ( Model, Effect )
startAgentGame humanSide model =
    case model.engineStatus of
        EngineLoading ->
            ( model, NoEffect )

        EngineThinking ->
            ( model, NoEffect )

        currentStatus ->
            let
                game =
                    { init
                        | disclaimerAccepted = True
                        , orientation = humanSide
                        , agentSide = Just (opposite humanSide)
                        , engineStatus = currentStatus
                        , engineBackend = model.engineBackend
                        , nextRequestId = model.nextRequestId + 1
                    }
            in
            case currentStatus of
                EngineReady ->
                    requestOpponentMove game

                _ ->
                    ( { game | engineStatus = EngineLoading }, LoadEngineEffect )


resetGame : Model -> ( Model, Effect )
resetGame model =
    let
        game =
            { init
                | disclaimerAccepted = True
                , orientation = model.orientation
                , agentSide = model.agentSide
                , engineStatus = readyAfterCancellation model.engineStatus
                , engineBackend = model.engineBackend
                , nextRequestId = model.nextRequestId + 1
            }
    in
    requestOpponentMove game


readyAfterCancellation : EngineStatus -> EngineStatus
readyAfterCancellation status =
    case status of
        EngineThinking ->
            EngineReady

        _ ->
            status


canPlayerMove : Model -> Bool
canPlayerMove model =
    model.winner
        == Nothing
        && (case model.agentSide of
                Nothing ->
                    model.engineStatus /= EngineThinking

                Just agentSide ->
                    model.turn /= agentSide && model.engineStatus == EngineReady
           )


requestOpponentMove : Model -> ( Model, Effect )
requestOpponentMove model =
    if model.agentSide == Just model.turn then
        beginEngineRequest OpponentMoveRequest model

    else
        ( model, NoEffect )


beginEngineRequest : EngineRequestPurpose -> Model -> ( Model, Effect )
beginEngineRequest purpose model =
    case ( model.engineStatus, model.winner ) of
        ( EngineReady, Nothing ) ->
            let
                requestId =
                    model.nextRequestId
            in
            ( { model
                | engineStatus = EngineThinking
                , selected = Nothing
                , suggestion = Nothing
                , pendingRequest = Just { id = requestId, purpose = purpose }
                , nextRequestId = requestId + 1
              }
            , RequestMoveEffect requestId (buildFen model) (engineLegalMoves model)
            )

        _ ->
            ( model, NoEffect )


handleEngineEvent : Decode.Value -> Model -> ( Model, Effect )
handleEngineEvent value model =
    case Decode.decodeValue engineEventDecoder value of
        Ok (EngineLoaded backend) ->
            if model.engineStatus == EngineLoading then
                requestOpponentMove
                    { model
                        | engineStatus = EngineReady
                        , engineBackend = Just backend
                        , pendingRequest = Nothing
                    }

            else
                ( model, NoEffect )

        Ok (EngineMoveSuggested requestId from to value_) ->
            handleEngineMove requestId from to value_ model

        Ok (EngineErrored requestId message) ->
            handleEngineError requestId message model

        Err decodeError ->
            ( { model
                | engineStatus = EngineFailed (Decode.errorToString decodeError)
                , pendingRequest = Nothing
              }
            , NoEffect
            )


handleEngineMove : Int -> Int -> Int -> Float -> Model -> ( Model, Effect )
handleEngineMove requestId from to value_ model =
    case model.pendingRequest of
        Just pending ->
            if pending.id /= requestId then
                ( model, NoEffect )

            else
                let
                    fromPosition =
                        engineSquareToPosition from

                    toPosition =
                        engineSquareToPosition to

                    readyModel =
                        { model | engineStatus = EngineReady, pendingRequest = Nothing }
                in
                case pending.purpose of
                    AnalysisRequest ->
                        ( { readyModel
                            | suggestion =
                                Just
                                    { from = fromPosition
                                    , to = toPosition
                                    , value = value_
                                    }
                          }
                        , NoEffect
                        )

                    OpponentMoveRequest ->
                        if model.agentSide == Just model.turn && isLegalMove model.turn fromPosition toPosition model.pieces then
                            ( movePiece fromPosition toPosition readyModel, NoEffect )

                        else
                            ( { readyModel | engineStatus = EngineFailed "agent returned an illegal move" }, NoEffect )

        Nothing ->
            ( model, NoEffect )


handleEngineError : Maybe Int -> String -> Model -> ( Model, Effect )
handleEngineError requestId message model =
    let
        appliesToCurrentRequest =
            case ( requestId, model.pendingRequest ) of
                ( Nothing, _ ) ->
                    True

                ( Just id, Just pending ) ->
                    id == pending.id

                _ ->
                    False
    in
    if appliesToCurrentRequest then
        ( { model | engineStatus = EngineFailed message, pendingRequest = Nothing }, NoEffect )

    else
        ( model, NoEffect )


type EngineEvent
    = EngineLoaded String
    | EngineMoveSuggested Int Int Int Float
    | EngineErrored (Maybe Int) String


engineEventDecoder : Decoder EngineEvent
engineEventDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\tag ->
                case tag of
                    "loaded" ->
                        Decode.map EngineLoaded (Decode.field "backend" Decode.string)

                    "move" ->
                        Decode.map4 EngineMoveSuggested
                            (Decode.field "requestId" Decode.int)
                            (Decode.field "from" Decode.int)
                            (Decode.field "to" Decode.int)
                            (Decode.field "value" Decode.float)

                    "error" ->
                        Decode.map2 EngineErrored
                            (Decode.maybe (Decode.field "requestId" Decode.int))
                            (Decode.field "message" Decode.string)

                    _ ->
                        Decode.fail ("unknown engine event type: " ++ tag)
            )


{-| The JS/WebGPU engine (assets/engine/) numbers squares `rank*9 + file`
with Red's back rank as rank 0 -- the opposite of this module's own
`Position` convention, where Black's back rank is rank 0 (see
`initialPieces`). `buildFen`/`engineSquareToPosition` are the only two
places that mapping has to be kept straight.
-}
engineSquareToPosition : Int -> Position
engineSquareToPosition index =
    let
        file =
            modBy 9 index

        engineRank =
            index // 9
    in
    ( file, 9 - engineRank )


{-| Inverse of `engineSquareToPosition`: this module's `Position` -> the
engine's `rank*9 + file` (Red's back rank = 0) square index.
-}
toEngineIndex : Position -> Int
toEngineIndex ( file, rank ) =
    (9 - rank) * 9 + file


{-| The current side-to-move's legal moves, in the engine's square
numbering -- sent alongside the FEN so the JS/WebGPU side never has to
compute legality itself; Elm is now the single source of truth for that.
-}
engineLegalMoves : Model -> List { from : Int, to : Int }
engineLegalMoves model =
    generateLegalMoves model.turn model.pieces
        |> List.map (\( from, to ) -> { from = toEngineIndex from, to = toEngineIndex to })


{-| Serialize the board to the FEN dialect the engine (and Pikafish) use:
ranks listed from the engine's rank 9 (Black's back rank) down to rank 0
(Red's back rank), left-to-right within each rank.
-}
buildFen : Model -> String
buildFen model =
    let
        rankFen engineRank =
            let
                elmRank =
                    9 - engineRank
            in
            List.range 0 8
                |> List.map (\file -> pieceAt ( file, elmRank ) model.pieces)
                |> runLengthEncodeFen

        ranks =
            List.range 0 9
                |> List.reverse
                |> List.map rankFen

        turnChar =
            if model.turn == Red then
                "w"

            else
                "b"
    in
    String.join "/" ranks ++ " " ++ turnChar ++ " - - 0 1"


runLengthEncodeFen : List (Maybe Piece) -> String
runLengthEncodeFen cells =
    let
        accumulate cell ( acc, emptyRun ) =
            case cell of
                Nothing ->
                    ( acc, emptyRun + 1 )

                Just piece ->
                    let
                        flushed =
                            if emptyRun > 0 then
                                acc ++ String.fromInt emptyRun

                            else
                                acc
                    in
                    ( flushed ++ fenChar piece, 0 )

        ( body, trailingEmpty ) =
            List.foldl accumulate ( "", 0 ) cells
    in
    if trailingEmpty > 0 then
        body ++ String.fromInt trailingEmpty

    else
        body


fenChar : Piece -> String
fenChar piece =
    let
        base =
            case piece.kind of
                General ->
                    "k"

                Advisor ->
                    "a"

                Elephant ->
                    "b"

                Horse ->
                    "n"

                Chariot ->
                    "r"

                Cannon ->
                    "c"

                Soldier ->
                    "p"
    in
    if piece.side == Red then
        String.toUpper base

    else
        base


selectPosition : Position -> Model -> Model
selectPosition position model =
    if model.winner /= Nothing then
        model

    else
        case ( model.selected, pieceAt position model.pieces ) of
            ( Nothing, Nothing ) ->
                model

            ( Nothing, Just piece ) ->
                if piece.side == model.turn then
                    { model | selected = Just position }

                else
                    model

            ( Just from, Just piece ) ->
                if piece.side == model.turn then
                    { model | selected = Just position }

                else if isLegalMove model.turn from position model.pieces then
                    movePiece from position model

                else
                    model

            ( Just from, Nothing ) ->
                if isLegalMove model.turn from position model.pieces then
                    movePiece from position model

                else
                    model


movePiece : Position -> Position -> Model -> Model
movePiece from to model =
    case pieceAt from model.pieces of
        Nothing ->
            model

        Just _ ->
            let
                newPieces =
                    applyMove from to model.pieces

                newTurn =
                    opposite model.turn
            in
            { model
                | pieces = newPieces
                , selected = Nothing
                , turn = newTurn
                , lastMove = Just ( from, to )
                , suggestion = Nothing
                , winner =
                    if isGameOver newTurn newPieces then
                        Just model.turn

                    else
                        Nothing
            }


{-| Board squares after moving `from` -> `to`, without any legality check
(used both by real moves and by `leavesInCheck`'s "try it and see").
-}
applyMove : Position -> Position -> List ( Position, Piece ) -> List ( Position, Piece )
applyMove from to pieces =
    case pieceAt from pieces of
        Nothing ->
            pieces

        Just piece ->
            ( to, piece ) :: List.filter (\( position, _ ) -> position /= from && position /= to) pieces


{-| Is `from -> to` consistent with how this piece type is allowed to
move, ignoring whether it leaves the mover's own general in check
(`isLegalMove` below is the one that also accounts for that).
-}
pseudoLegalMove : Position -> Position -> List ( Position, Piece ) -> Bool
pseudoLegalMove from to pieces =
    case pieceAt from pieces of
        Nothing ->
            False

        Just piece ->
            let
                ( fromFile, fromRank ) =
                    from

                ( toFile, toRank ) =
                    to

                dx =
                    toFile - fromFile

                dy =
                    toRank - fromRank

                targetIsFriendly =
                    pieceAt to pieces
                        |> Maybe.map (\target -> target.side == piece.side)
                        |> Maybe.withDefault False
            in
            from
                /= to
                && not targetIsFriendly
                && (case piece.kind of
                        General ->
                            (abs dx + abs dy == 1 && inPalace piece.side to)
                                || (dx
                                        == 0
                                        && piecesBetween from to pieces
                                        == 0
                                        && (pieceAt to pieces
                                                |> Maybe.map (\target -> target.side /= piece.side && target.kind == General)
                                                |> Maybe.withDefault False
                                           )
                                   )

                        Advisor ->
                            abs dx == 1 && abs dy == 1 && inPalace piece.side to

                        Elephant ->
                            abs dx
                                == 2
                                && abs dy
                                == 2
                                && onOwnSide piece.side toRank
                                && isEmpty ( fromFile + dx // 2, fromRank + dy // 2 ) pieces

                        Horse ->
                            if abs dx == 2 && abs dy == 1 then
                                isEmpty ( fromFile + dx // 2, fromRank ) pieces

                            else if abs dx == 1 && abs dy == 2 then
                                isEmpty ( fromFile, fromRank + dy // 2 ) pieces

                            else
                                False

                        Chariot ->
                            (dx == 0 || dy == 0) && piecesBetween from to pieces == 0

                        Cannon ->
                            if dx /= 0 && dy /= 0 then
                                False

                            else
                                case pieceAt to pieces of
                                    Nothing ->
                                        piecesBetween from to pieces == 0

                                    Just _ ->
                                        piecesBetween from to pieces == 1

                        Soldier ->
                            soldierMove piece.side fromRank dx dy
                   )


soldierMove : Side -> Int -> Int -> Int -> Bool
soldierMove side fromRank dx dy =
    let
        forward =
            if side == Red then
                -1

            else
                1

        crossedRiver =
            if side == Red then
                fromRank <= 4

            else
                fromRank >= 5
    in
    (dx == 0 && dy == forward) || (crossedRiver && abs dx == 1 && dy == 0)


piecesBetween : Position -> Position -> List ( Position, Piece ) -> Int
piecesBetween ( fromFile, fromRank ) ( toFile, toRank ) pieces =
    let
        liesBetween ( file, rank ) =
            if fromFile == toFile then
                file == fromFile && rank > min fromRank toRank && rank < max fromRank toRank

            else
                rank == fromRank && file > min fromFile toFile && file < max fromFile toFile
    in
    pieces
        |> List.filter (\( position, _ ) -> liesBetween position)
        |> List.length


{-| Pseudo-legal (piece-movement-rule-correct) **and** doesn't leave the
mover's own general in check -- the two together are what "legal" means.
-}
isLegalMove : Side -> Position -> Position -> List ( Position, Piece ) -> Bool
isLegalMove side from to pieces =
    pseudoLegalMove from to pieces && not (leavesInCheck side from to pieces)


leavesInCheck : Side -> Position -> Position -> List ( Position, Piece ) -> Bool
leavesInCheck side from to pieces =
    inCheck side (applyMove from to pieces)


{-| Every legal move for `side` from the current position, as `(from, to)`
pairs. Brute-force (every piece x every square, ~90 candidates each) --
plenty fast for a UI action, not meant for deep search.
-}
generateLegalMoves : Side -> List ( Position, Piece ) -> List ( Position, Position )
generateLegalMoves side pieces =
    pieces
        |> List.filter (\( _, piece ) -> piece.side == side)
        |> List.concatMap
            (\( from, _ ) ->
                boardPositions
                    |> List.filter (\to -> isLegalMove side from to pieces)
                    |> List.map (\to -> ( from, to ))
            )


{-| Xiangqi has no stalemate draw: a side with no legal moves has lost,
whether checkmated or merely stalemated.
-}
isGameOver : Side -> List ( Position, Piece ) -> Bool
isGameOver side pieces =
    findGeneral side pieces == Nothing || List.isEmpty (generateLegalMoves side pieces)


{-| Standard perft: count leaf positions reached at exactly `depth` plies.
Exists mainly so `tests/` can hold this module's move generator to the
same trusted node counts (44 at depth 1, 1920 at depth 2, ...) that
`../../tinyfih/julia/test/runtests.jl` and
`../../tinyfih/web-engine/test/perft_crosscheck.mjs` already verified
against a real Pikafish binary -- same ground truth, third independent
implementation.
-}
perft : Int -> Side -> List ( Position, Piece ) -> Int
perft depth side pieces =
    if depth <= 0 then
        1

    else
        let
            moves =
                generateLegalMoves side pieces
        in
        if depth == 1 then
            List.length moves

        else
            moves
                |> List.map (\( from, to ) -> perft (depth - 1) (opposite side) (applyMove from to pieces))
                |> List.sum


inCheck : Side -> List ( Position, Piece ) -> Bool
inCheck side pieces =
    case findGeneral side pieces of
        Nothing ->
            False

        Just generalPos ->
            isSquareAttacked generalPos (opposite side) pieces


findGeneral : Side -> List ( Position, Piece ) -> Maybe Position
findGeneral side pieces =
    pieces
        |> List.filter (\( _, piece ) -> piece.side == side && piece.kind == General)
        |> List.head
        |> Maybe.map Tuple.first


{-| Is `target` attacked by any piece belonging to `by`? Walks outward
_from_ `target` per piece-movement pattern (an allocation-free reverse
scan) rather than generating every attacker's full move list -- mirrors
`../../tinyfih/web-engine/rules.js`'s `isSquareAttacked` exactly (that
version is cross-checked against Pikafish's own perft counts; this is a
straight port of the same algorithm into Elm's `(file, rank)` tuples).
Includes the "flying general" rule (two generals facing off on an open
file count as mutual check).
-}
isSquareAttacked : Position -> Side -> List ( Position, Piece ) -> Bool
isSquareAttacked target by pieces =
    orthogonalAttacks target by pieces
        || knightAttacks target by pieces
        || bishopAttacks target by pieces
        || advisorAttacks target by pieces
        || pawnAttacks target by pieces
        || flyingGeneralAttack target by pieces


orthoDirs : List ( Int, Int )
orthoDirs =
    [ ( 0, 1 ), ( 0, -1 ), ( 1, 0 ), ( -1, 0 ) ]


diagDirs : List ( Int, Int )
diagDirs =
    [ ( 1, 1 ), ( 1, -1 ), ( -1, 1 ), ( -1, -1 ) ]


knightOffsets : List ( Int, Int )
knightOffsets =
    [ ( 1, 2 ), ( 1, -2 ), ( -1, 2 ), ( -1, -2 ), ( 2, 1 ), ( 2, -1 ), ( -2, 1 ), ( -2, -1 ) ]


inBoard : Position -> Bool
inBoard ( file, rank ) =
    file >= 0 && file <= 8 && rank >= 0 && rank <= 9


step : Position -> Int -> Int -> Position
step ( file, rank ) df dr =
    ( file + df, rank + dr )


{-| Rook/Chariot (direct), Cannon (through exactly one screen), General
(adjacent, within its own palace) all attack along the four orthogonal
rays -- one scan per direction covers all three.
-}
orthogonalAttacks : Position -> Side -> List ( Position, Piece ) -> Bool
orthogonalAttacks target by pieces =
    orthoDirs |> List.any (\( df, dr ) -> rayAttack target (step target df dr) by pieces df dr)


rayAttack : Position -> Position -> Side -> List ( Position, Piece ) -> Int -> Int -> Bool
rayAttack target pos by pieces df dr =
    if not (inBoard pos) then
        False

    else
        case pieceAt pos pieces of
            Nothing ->
                rayAttack target (step pos df dr) by pieces df dr

            Just piece ->
                if piece.side == by && piece.kind == Chariot then
                    True

                else if piece.side == by && piece.kind == General && pos == step target df dr && inPalace by target then
                    True

                else
                    rayAttackPastScreen (step pos df dr) by pieces df dr


rayAttackPastScreen : Position -> Side -> List ( Position, Piece ) -> Int -> Int -> Bool
rayAttackPastScreen pos by pieces df dr =
    if not (inBoard pos) then
        False

    else
        case pieceAt pos pieces of
            Nothing ->
                rayAttackPastScreen (step pos df dr) by pieces df dr

            Just piece ->
                piece.side == by && piece.kind == Cannon


{-| Horse: reverse of its usual (1,2)/(2,1) jump, still subject to the
"leg" blocking square.
-}
knightAttacks : Position -> Side -> List ( Position, Piece ) -> Bool
knightAttacks target by pieces =
    knightOffsets
        |> List.any
            (\( df, dr ) ->
                let
                    src =
                        step target -df -dr
                in
                inBoard src
                    && isEmpty (legSquare src df dr) pieces
                    && (pieceAt src pieces
                            |> Maybe.map (\p -> p.side == by && p.kind == Horse)
                            |> Maybe.withDefault False
                       )
            )


legSquare : Position -> Int -> Int -> Position
legSquare ( file, rank ) df dr =
    if abs df == 2 then
        ( file + df // 2, rank )

    else
        ( file, rank + dr // 2 )


{-| Elephant: reverse of its usual 2-step diagonal, still blocked by the midpoint and confined to its own half.
-}
bishopAttacks : Position -> Side -> List ( Position, Piece ) -> Bool
bishopAttacks ( f0, r0 ) by pieces =
    diagDirs
        |> List.any
            (\( df, dr ) ->
                let
                    src =
                        ( f0 - 2 * df, r0 - 2 * dr )

                    mid =
                        ( f0 - df, r0 - dr )
                in
                inBoard src
                    && onOwnSide by r0
                    && isEmpty mid pieces
                    && (pieceAt src pieces
                            |> Maybe.map (\p -> p.side == by && p.kind == Elephant)
                            |> Maybe.withDefault False
                       )
            )


advisorAttacks : Position -> Side -> List ( Position, Piece ) -> Bool
advisorAttacks target by pieces =
    diagDirs
        |> List.any
            (\( df, dr ) ->
                let
                    src =
                        step target -df -dr
                in
                inBoard src
                    && inPalace by target
                    && (pieceAt src pieces
                            |> Maybe.map (\p -> p.side == by && p.kind == Advisor)
                            |> Maybe.withDefault False
                       )
            )


pawnAttacks : Position -> Side -> List ( Position, Piece ) -> Bool
pawnAttacks ( f0, r0 ) by pieces =
    let
        forward =
            if by == Red then
                -1

            else
                1

        forwardSrc =
            ( f0, r0 - forward )

        isSoldierOf src =
            pieceAt src pieces
                |> Maybe.map (\p -> p.side == by && p.kind == Soldier)
                |> Maybe.withDefault False

        forwardHit =
            inBoard forwardSrc && isSoldierOf forwardSrc

        sideHit =
            [ -1, 1 ]
                |> List.any
                    (\df ->
                        let
                            src =
                                ( f0 + df, r0 )
                        in
                        inBoard src && not (onOwnSide by r0) && isSoldierOf src
                    )
    in
    forwardHit || sideHit


{-| Two generals facing each other on an open file counts as mutual check,
even though a general's own step-move never reaches that far.
-}
flyingGeneralAttack : Position -> Side -> List ( Position, Piece ) -> Bool
flyingGeneralAttack ( f0, r0 ) by pieces =
    case findGeneral by pieces of
        Nothing ->
            False

        Just ( gf, gr ) ->
            if gf /= f0 || ( gf, gr ) == ( f0, r0 ) then
                False

            else
                List.range (min gr r0 + 1) (max gr r0 - 1)
                    |> List.all (\r -> isEmpty ( f0, r ) pieces)


inPalace : Side -> Position -> Bool
inPalace side ( file, rank ) =
    file
        >= 3
        && file
        <= 5
        && (if side == Red then
                rank >= 7 && rank <= 9

            else
                rank >= 0 && rank <= 2
           )


onOwnSide : Side -> Int -> Bool
onOwnSide side rank =
    if side == Red then
        rank >= 5

    else
        rank <= 4


isEmpty : Position -> List ( Position, Piece ) -> Bool
isEmpty position pieces =
    pieceAt position pieces == Nothing


pieceAt : Position -> List ( Position, Piece ) -> Maybe Piece
pieceAt position pieces =
    pieces
        |> List.filter (\( candidate, _ ) -> candidate == position)
        |> List.head
        |> Maybe.map Tuple.second


opposite : Side -> Side
opposite side =
    if side == Red then
        Black

    else
        Red


sideName : Side -> String
sideName side =
    if side == Red then
        "red"

    else
        "black"


view : Model -> Html Msg
view model =
    div [ class "xiangqi-content" ]
        [ h1 [] [ text "象棋" ]
        , p [ class "xiangqi-intro" ] [ text "Play Chinese chess against a lightweight reinforcement-learning agent running entirely in your browser." ]
        , if model.disclaimerAccepted then
            viewGame model

          else
            viewDisclaimer
        ]


viewDisclaimer : Html Msg
viewDisclaimer =
    div [ class "xiangqi-disclaimer" ]
        [ span [ class "development-marker" ] [ text "// compute notice" ]
        , p [] [ text "This experiment runs a Xiangqi agent locally using WebGPU when available, with a plain-JavaScript CPU fallback." ]
        , p [] [ text "The agent loads only when requested and may use significant GPU, memory, and battery resources." ]
        , button [ type_ "button", class "xiangqi-primary-button", onClick AcceptDisclaimer ] [ text "I understand — open board" ]
        ]


viewGame : Model -> Html Msg
viewGame model =
    div []
        [ div [ class "xiangqi-toolbar" ]
            [ div [ class "xiangqi-turn" ]
                [ span [ class "development-marker" ] [ text "turn" ]
                , span [ class ("turn-side " ++ sideName model.turn) ] [ text (sideName model.turn) ]
                , viewTurnOwner model
                ]
            , div [ class "xiangqi-actions" ]
                [ button [ type_ "button", class "xiangqi-button", onClick SwitchSide ]
                    [ text ("view from " ++ sideName (opposite model.orientation)) ]
                , button [ type_ "button", class "xiangqi-button", onClick Reset ] [ text "reset" ]
                ]
            ]
        , viewGameOverBanner model
        , div [ class "xiangqi-workspace" ]
            [ viewBoard model
            , viewEvaluation model
            ]
        , p [ class "xiangqi-help" ]
            [ text
                (case model.agentSide of
                    Nothing ->
                        "Select a piece and then its destination. Full legality, check, and checkmate/stalemate are enforced."

                    Just agentSide ->
                        "You are " ++ sideName (opposite agentSide) ++ ". The agent is " ++ sideName agentSide ++ " and moves automatically."
                )
            ]
        ]


viewTurnOwner : Model -> Html Msg
viewTurnOwner model =
    case model.agentSide of
        Nothing ->
            text ""

        Just agentSide ->
            span [ class "turn-owner" ]
                [ text
                    (if model.turn == agentSide then
                        "agent"

                     else
                        "you"
                    )
                ]


viewGameOverBanner : Model -> Html Msg
viewGameOverBanner model =
    case model.winner of
        Nothing ->
            text ""

        Just winner ->
            p [ class "xiangqi-game-over" ]
                [ text (sideName winner ++ " wins — " ++ sideName (opposite winner) ++ " has no legal move. ")
                , button [ type_ "button", class "xiangqi-button", onClick Reset ] [ text "play again" ]
                ]


viewBoard : Model -> Html Msg
viewBoard model =
    let
        boardInteractive =
            canPlayerMove model

        legalTargets =
            if boardInteractive then
                case model.selected of
                    Nothing ->
                        []

                    Just from ->
                        boardPositions
                            |> List.filter (\to -> isLegalMove model.turn from to model.pieces)

            else
                []
    in
    div [ class "xiangqi-board-wrap" ]
        [ div
            [ class "xiangqi-board"
            , attribute "aria-label" ("Interactive Chinese chess board viewed from " ++ sideName model.orientation)
            , attribute "aria-busy"
                (if model.engineStatus == EngineThinking then
                    "true"

                 else
                    "false"
                )
            ]
            (div [ class "xiangqi-river" ] [ span [] [ text "楚河" ], span [] [ text "漢界" ] ]
                :: List.map (viewSquare model legalTargets boardInteractive) boardPositions
            )
        ]


viewSquare : Model -> List Position -> Bool -> Position -> Html Msg
viewSquare model legalTargets boardInteractive position =
    let
        ( file, rank ) =
            position

        displayFile =
            if model.orientation == Red then
                file

            else
                8 - file

        displayRank =
            if model.orientation == Red then
                rank

            else
                9 - rank

        lastMoveSquare =
            model.lastMove
                |> Maybe.map (\( from, to ) -> position == from || position == to)
                |> Maybe.withDefault False

        suggestedSquare =
            model.suggestion
                |> Maybe.map (\s -> position == s.from || position == s.to)
                |> Maybe.withDefault False
    in
    button
        [ type_ "button"
        , classList
            [ ( "xiangqi-square", True )
            , ( "selected", model.selected == Just position )
            , ( "legal-target", List.member position legalTargets )
            , ( "last-move", lastMoveSquare )
            , ( "suggested", suggestedSquare )
            ]
        , style "left" (String.fromFloat (toFloat displayFile / 8 * 100) ++ "%")
        , style "top" (String.fromFloat (toFloat displayRank / 9 * 100) ++ "%")
        , attribute "aria-label" (squareLabel position model.pieces)
        , disabled (not boardInteractive)
        , onClick (Select position)
        ]
        [ case pieceAt position model.pieces of
            Just piece ->
                span [ class ("xiangqi-piece " ++ sideName piece.side) ] [ text (pieceGlyph piece) ]

            Nothing ->
                text ""
        ]


viewEvaluation : Model -> Html Msg
viewEvaluation model =
    let
        score =
            model.suggestion |> Maybe.map .value |> Maybe.withDefault 0

        -- score is from the side-to-move's perspective; flip to a fixed
        -- red/black axis for the bar.
        redScore =
            if model.turn == Red then
                score

            else
                -score

        barPercent =
            ((redScore + 1) / 2 * 100)
                |> clamp 0 100

        statusText =
            case model.engineStatus of
                EngineIdle ->
                    "agent offline"

                EngineLoading ->
                    "loading agent…"

                EngineReady ->
                    "agent ready (" ++ Maybe.withDefault "cpu" model.engineBackend ++ ")"

                EngineThinking ->
                    "thinking…"

                EngineFailed message ->
                    "agent error: " ++ message
    in
    div [ class "xiangqi-evaluation" ]
        [ span [ class "development-marker" ]
            [ text
                (case model.agentSide of
                    Nothing ->
                        "// blunder detector"

                    Just _ ->
                        "// local opponent"
                )
            ]
        , div [ class "evaluation-body" ]
            [ div
                [ class "evaluation-bar"
                , attribute "aria-label"
                    (if model.suggestion == Nothing then
                        "Neutral evaluation; local agent unavailable"

                     else
                        "Evaluation " ++ String.fromFloat redScore ++ " (positive favors red)"
                    )
                ]
                [ div [ class "evaluation-black", style "flex" (String.fromFloat (100 - barPercent)) ] []
                , div [ class "evaluation-midpoint" ] []
                , div [ class "evaluation-red", style "flex" (String.fromFloat barPercent) ] []
                ]
            , div [ class "evaluation-labels" ]
                [ span [] [ text "black" ]
                , span [ class "evaluation-score" ]
                    [ text
                        (model.suggestion
                            |> Maybe.map (\_ -> String.fromFloat (toFloat (round (redScore * 100)) / 100))
                            |> Maybe.withDefault "0.0"
                        )
                    ]
                , span [] [ text "red" ]
                ]
            ]
        , p [ class "agent-status" ] [ text statusText ]
        , p [ class "agent-description" ] [ text "Runs a lightweight self-play-trained network locally (WebGPU if available, plain JS otherwise) — nothing is sent anywhere." ]
        , viewSuggestion model
        , viewEngineButton model
        , viewOpponentControls model
        ]


viewSuggestion : Model -> Html Msg
viewSuggestion model =
    case model.suggestion of
        Nothing ->
            text ""

        Just suggestion ->
            p [ class "agent-suggestion" ]
                [ text
                    ("suggested: "
                        ++ squareLabel suggestion.from model.pieces
                        ++ " -> "
                        ++ squareLabel suggestion.to model.pieces
                    )
                ]


viewEngineButton : Model -> Html Msg
viewEngineButton model =
    case model.agentSide of
        Just _ ->
            case model.engineStatus of
                EngineFailed _ ->
                    button [ type_ "button", class "agent-placeholder-button", onClick RequestEngineLoad ] [ text "retry agent" ]

                _ ->
                    text ""

        Nothing ->
            case model.engineStatus of
                EngineIdle ->
                    button [ type_ "button", class "agent-placeholder-button", onClick RequestEngineLoad ] [ text "load for analysis" ]

                EngineLoading ->
                    button [ type_ "button", class "agent-placeholder-button", disabled True ] [ text "loading…" ]

                EngineReady ->
                    button [ type_ "button", class "agent-placeholder-button", onClick RequestBestMove ] [ text "suggest a move" ]

                EngineThinking ->
                    button [ type_ "button", class "agent-placeholder-button", disabled True ] [ text "thinking…" ]

                EngineFailed _ ->
                    button [ type_ "button", class "agent-placeholder-button", onClick RequestEngineLoad ] [ text "retry loading agent" ]


viewOpponentControls : Model -> Html Msg
viewOpponentControls model =
    case model.agentSide of
        Nothing ->
            let
                canStart =
                    model.engineStatus /= EngineLoading && model.engineStatus /= EngineThinking
            in
            div [ class "agent-controls" ]
                [ span [ class "agent-controls-label" ] [ text "play against agent" ]
                , div [ class "agent-side-buttons" ]
                    [ button
                        [ type_ "button"
                        , class "agent-side-button red"
                        , disabled (not canStart)
                        , onClick (StartAgentGame Red)
                        ]
                        [ text "as red" ]
                    , button
                        [ type_ "button"
                        , class "agent-side-button black"
                        , disabled (not canStart)
                        , onClick (StartAgentGame Black)
                        ]
                        [ text "as black" ]
                    ]
                ]

        Just agentSide ->
            div [ class "agent-controls" ]
                [ p [ class "agent-matchup" ]
                    [ text ("you: " ++ sideName (opposite agentSide) ++ " / agent: " ++ sideName agentSide) ]
                , button [ type_ "button", class "agent-placeholder-button", onClick StopAgentGame ] [ text "stop match" ]
                ]


squareLabel : Position -> List ( Position, Piece ) -> String
squareLabel ( file, rank ) pieces =
    let
        coordinate =
            "file " ++ String.fromInt (file + 1) ++ ", rank " ++ String.fromInt (10 - rank)
    in
    case pieceAt ( file, rank ) pieces of
        Nothing ->
            "Empty, " ++ coordinate

        Just piece ->
            sideName piece.side ++ " " ++ pieceName piece.kind ++ ", " ++ coordinate


pieceGlyph : Piece -> String
pieceGlyph piece =
    case ( piece.side, piece.kind ) of
        ( Red, General ) ->
            "帥"

        ( Black, General ) ->
            "將"

        ( Red, Advisor ) ->
            "仕"

        ( Black, Advisor ) ->
            "士"

        ( Red, Elephant ) ->
            "相"

        ( Black, Elephant ) ->
            "象"

        ( Red, Horse ) ->
            "傌"

        ( Black, Horse ) ->
            "馬"

        ( Red, Chariot ) ->
            "俥"

        ( Black, Chariot ) ->
            "車"

        ( Red, Cannon ) ->
            "炮"

        ( Black, Cannon ) ->
            "砲"

        ( Red, Soldier ) ->
            "兵"

        ( Black, Soldier ) ->
            "卒"


pieceName : PieceKind -> String
pieceName kind =
    case kind of
        General ->
            "general"

        Advisor ->
            "advisor"

        Elephant ->
            "elephant"

        Horse ->
            "horse"

        Chariot ->
            "chariot"

        Cannon ->
            "cannon"

        Soldier ->
            "soldier"


boardPositions : List Position
boardPositions =
    List.concatMap (\rank -> List.map (\file -> ( file, rank )) (List.range 0 8)) (List.range 0 9)


initialPieces : List ( Position, Piece )
initialPieces =
    let
        backRank side rank =
            List.map2
                (\file kind -> ( ( file, rank ), Piece side kind ))
                (List.range 0 8)
                [ Chariot, Horse, Elephant, Advisor, General, Advisor, Elephant, Horse, Chariot ]

        soldiers side rank =
            List.map (\file -> ( ( file, rank ), Piece side Soldier )) [ 0, 2, 4, 6, 8 ]
    in
    backRank Black 0
        ++ [ ( ( 1, 2 ), Piece Black Cannon ), ( ( 7, 2 ), Piece Black Cannon ) ]
        ++ soldiers Black 3
        ++ soldiers Red 6
        ++ [ ( ( 1, 7 ), Piece Red Cannon ), ( ( 7, 7 ), Piece Red Cannon ) ]
        ++ backRank Red 9


css : String
css =
    """
    .xiangqi-content { max-width: 900px; }
    .xiangqi-intro { color: var(--muted-color) !important; margin-bottom: 2rem !important; }
    .xiangqi-disclaimer { max-width: 620px; padding: 1.5rem; border: 1px solid var(--border-color); border-left: 3px solid var(--accent-color); border-radius: 6px; background: var(--surface-color); }
    .xiangqi-disclaimer p { color: var(--muted-color) !important; }
    .development-marker { color: var(--accent-color); font-size: .68rem; letter-spacing: .08em; text-transform: uppercase; }
    .xiangqi-primary-button, .xiangqi-button, .agent-placeholder-button { padding: .5rem .75rem; border: 1px solid var(--border-color); border-radius: 4px; font: inherit; font-size: .74rem; cursor: pointer; }
    .xiangqi-primary-button { background: var(--accent-color); color: #1e1c2e; }
    .xiangqi-button { color: var(--text-color); background: var(--surface-color); }
    .xiangqi-primary-button:hover, .xiangqi-button:hover { border-color: var(--accent-color); }
    .xiangqi-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 1rem; width: min(100%, 760px); margin-bottom: .8rem; }
    .xiangqi-turn { display: flex; align-items: center; gap: .55rem; }
    .turn-side { padding: .12rem .5rem; border: 1px solid currentColor; border-radius: 999px; font-size: .72rem; }
    .turn-side.red { color: #b43b36; }
    .turn-side.black { color: var(--text-color); }
    .turn-owner { color: var(--muted-color); font-size: .7rem; }
    .xiangqi-actions { display: flex; gap: .5rem; }
    .xiangqi-workspace { display: flex; align-items: stretch; gap: 1rem; }
    .xiangqi-board-wrap { position: relative; width: min(100%, 600px); padding: 5.5%; border: 1px solid var(--border-color); border-radius: 6px; background: #cda66a; box-shadow: 0 12px 32px rgba(0, 0, 0, .2); }
    .xiangqi-board { position: relative; aspect-ratio: 8 / 9; background-color: #d9b777; background-image: repeating-linear-gradient(to right, transparent 0, transparent calc(12.5% - .5px), #5b4128 calc(12.5% - .5px), #5b4128 calc(12.5% + .5px)), repeating-linear-gradient(to bottom, transparent 0, transparent calc(11.111% - .5px), #5b4128 calc(11.111% - .5px), #5b4128 calc(11.111% + .5px)); border: 1px solid #5b4128; }
    .xiangqi-river { position: absolute; z-index: 1; left: 0; right: 0; top: 44.45%; height: 11.111%; display: flex; align-items: center; justify-content: space-around; background: #d9b777; border-top: 1px solid #5b4128; border-bottom: 1px solid #5b4128; color: #5b4128; font-family: serif; font-size: clamp(.9rem, 3vw, 1.65rem); letter-spacing: .35em; pointer-events: none; }
    .xiangqi-square { position: absolute; z-index: 2; width: 11.5%; aspect-ratio: 1; padding: 0; transform: translate(-50%, -50%); border: 0; border-radius: 50%; background: transparent; cursor: pointer; }
    .xiangqi-square:disabled { opacity: 1; cursor: default; }
    .xiangqi-square.last-move::after, .xiangqi-square.selected::after, .xiangqi-square.suggested::after { content: ""; position: absolute; inset: 12%; border: 2px solid rgba(42, 75, 112, .55); border-radius: 50%; }
    .xiangqi-square.legal-target::before { content: ""; position: absolute; z-index: 3; width: 18%; aspect-ratio: 1; top: 41%; left: 41%; border-radius: 50%; background: rgba(74, 140, 94, .75); pointer-events: none; }
    .xiangqi-square.selected::after { border-color: #9d2f2a; }
    .xiangqi-square.suggested::after { border-color: #4a8c5e; border-style: dashed; }
    .xiangqi-piece { position: absolute; z-index: 2; inset: 8%; display: grid; place-items: center; border: 2px solid currentColor; border-radius: 50%; background: #ead29c; font-family: serif; font-size: clamp(.82rem, 2.6vw, 1.45rem); font-weight: 700; line-height: 1; box-shadow: 0 2px 4px rgba(55, 35, 18, .42), inset 0 0 0 2px #ead29c, inset 0 0 0 3px currentColor; }
    .xiangqi-piece.black { color: #26211d; }
    .xiangqi-piece.red { color: #a8322d; }
    .xiangqi-evaluation { width: 145px; padding: 1rem; border: 1px solid var(--border-color); border-radius: 6px; background: var(--surface-color); }
    .evaluation-body { display: flex; gap: .55rem; height: 330px; margin: 1rem 0; }
    .evaluation-bar { position: relative; display: flex; flex-direction: column; width: 32px; overflow: hidden; border: 1px solid var(--border-color); border-radius: 3px; }
    .evaluation-black, .evaluation-red { flex: 1; }
    .evaluation-black { background: #252129; }
    .evaluation-red { background: #b2403b; }
    .evaluation-midpoint { position: absolute; z-index: 1; top: 50%; left: 0; right: 0; height: 2px; background: #ead29c; transform: translateY(-1px); }
    .evaluation-labels { display: flex; flex: 1; flex-direction: column; justify-content: space-between; color: var(--muted-color); font-size: .66rem; }
    .evaluation-score { color: var(--text-color); }
    .agent-status { margin: 0 !important; color: var(--accent-color) !important; font-size: .7rem !important; text-transform: uppercase; }
    .agent-description { margin: .5rem 0 !important; color: var(--muted-color) !important; font-size: .66rem !important; line-height: 1.5 !important; }
    .agent-suggestion { margin: 0 0 .5rem !important; color: var(--text-color) !important; font-size: .74rem !important; }
    .agent-placeholder-button { width: 100%; margin-top: .5rem; color: var(--text-color); background: var(--surface-color); border: 1px solid var(--border-color); border-radius: 4px; padding: .5rem; font: inherit; font-size: .74rem; cursor: pointer; }
    .agent-placeholder-button:hover:not(:disabled) { border-color: var(--accent-color); }
    .agent-placeholder-button:disabled { color: var(--muted-color); cursor: not-allowed; opacity: .6; }
    .agent-controls { margin-top: .75rem; padding-top: .75rem; border-top: 1px solid var(--border-color); }
    .agent-controls-label { display: block; margin-bottom: .45rem; color: var(--muted-color); font-size: .66rem; }
    .agent-side-buttons { display: grid; grid-template-columns: 1fr 1fr; gap: .35rem; }
    .agent-side-button { min-width: 0; padding: .45rem .25rem; border: 1px solid var(--border-color); border-radius: 4px; background: var(--surface-color); color: var(--text-color); font: inherit; font-size: .66rem; cursor: pointer; }
    .agent-side-button.red { color: #c8544e; }
    .agent-side-button:hover:not(:disabled) { border-color: var(--accent-color); }
    .agent-side-button:disabled { cursor: not-allowed; opacity: .5; }
    .agent-matchup { margin: 0 !important; color: var(--muted-color) !important; font-size: .66rem !important; line-height: 1.5 !important; }
    .xiangqi-help { max-width: 760px !important; color: var(--muted-color) !important; font-size: .72rem !important; }
    .xiangqi-game-over { display: flex; align-items: center; gap: .75rem; width: min(100%, 760px); margin: 0 0 .8rem !important; padding: .6rem .9rem; border: 1px solid var(--accent-color); border-radius: 6px; background: var(--surface-color); color: var(--text-color) !important; font-size: .8rem !important; }
    @media (max-width: 650px) {
      .xiangqi-toolbar { align-items: flex-start; flex-direction: column; }
      .xiangqi-workspace { flex-direction: column; }
      .xiangqi-board-wrap { padding: 7%; }
      .xiangqi-evaluation { width: 100%; }
      .evaluation-body { height: 40px; }
      .evaluation-bar { flex-direction: row; width: 100%; }
      .evaluation-midpoint { top: 0; bottom: 0; left: 50%; right: auto; width: 2px; height: auto; transform: translateX(-1px); }
      .evaluation-labels { display: none; }
    }
    """


cssStyles : Html msg
cssStyles =
    VirtualDom.node "style" [] [ text css ]
