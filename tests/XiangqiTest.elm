module XiangqiTest exposing (suite)

{-| Regression tests for Xiangqi's move generator -- the Elm port of the
rules engine in `../../tinyfih/` (see that repo's `julia/src/Attacks.jl` /
`web-engine/rules.js` for the original, cross-checked against a real
Pikafish binary).

The perft counts below aren't guesses: they're the same numbers Pikafish
itself produced for these exact positions (see
`../../tinyfih/julia/test/runtests.jl` and
`../../tinyfih/web-engine/test/perft_crosscheck.mjs`), reused here as a
third independent check on a third independent implementation rather than
re-deriving them from scratch. Depths are kept shallow (this module's
`List`-based board is nowhere near as fast as the bitboard/array versions,
and it doesn't need to be -- it only drives one UI click at a time) but
even depth 2 already exercises check detection, since some depth-1 pseudo
moves at the start position would leave the mover's own general exposed
if filtering were missing or wrong... except at the standard start
position none do, which is exactly why the check-detection-specific case
below uses a constructed position instead.

-}

import Expect
import Json.Encode as Encode
import Test exposing (Test, describe, test)
import Xiangqi exposing (Piece, PieceKind(..), Side(..), generateLegalMoves, inCheck, initialPieces, isGameOver, isSquareAttacked, perft)


suite : Test
suite =
    describe "Xiangqi rules engine"
        [ describe "perft (standard start position)"
            [ test "depth 1 == 44" <|
                \_ -> Expect.equal 44 (perft 1 Red initialPieces)
            , test "depth 2 == 1920" <|
                \_ -> Expect.equal 1920 (perft 2 Red initialPieces)
            ]
        , describe "check detection"
            [ test "standard start position: neither side is in check" <|
                \_ ->
                    Expect.equal ( False, False ) ( inCheck Red initialPieces, inCheck Black initialPieces )
            , test "flying general: open file between the two generals is mutual check" <|
                \_ ->
                    let
                        pieces =
                            [ ( ( 4, 0 ), Piece Black General ), ( ( 4, 9 ), Piece Red General ) ]
                    in
                    Expect.equal ( True, True ) ( inCheck Red pieces, inCheck Black pieces )
            , test "flying general: a blocker on the file removes the check" <|
                \_ ->
                    let
                        pieces =
                            [ ( ( 4, 0 ), Piece Black General )
                            , ( ( 4, 9 ), Piece Red General )
                            , ( ( 4, 5 ), Piece Red Soldier )
                            ]
                    in
                    Expect.equal ( False, False ) ( inCheck Red pieces, inCheck Black pieces )
            ]
        , describe "soldier attacks"
            [ test "a Red soldier attacks one rank forward (toward decreasing rank)" <|
                \_ ->
                    let
                        pieces =
                            [ ( ( 4, 0 ), Piece Black General ), ( ( 4, 5 ), Piece Red Soldier ) ]
                    in
                    Expect.equal True (isSquareAttacked ( 4, 4 ) Red pieces)
            , test "a Black soldier attacks one rank forward (toward increasing rank)" <|
                \_ ->
                    let
                        pieces =
                            [ ( ( 4, 9 ), Piece Red General ), ( ( 4, 4 ), Piece Black Soldier ) ]
                    in
                    Expect.equal True (isSquareAttacked ( 4, 5 ) Black pieces)
            , test "a soldier that has crossed the river also attacks sideways" <|
                \_ ->
                    let
                        pieces =
                            [ ( ( 4, 4 ), Piece Red Soldier ) ]
                    in
                    Expect.equal ( True, True ) ( isSquareAttacked ( 3, 4 ) Red pieces, isSquareAttacked ( 5, 4 ) Red pieces )
            , test "a soldier that has NOT crossed the river does not attack sideways" <|
                \_ ->
                    let
                        pieces =
                            [ ( ( 4, 6 ), Piece Red Soldier ) ]
                    in
                    Expect.equal ( False, False ) ( isSquareAttacked ( 3, 6 ) Red pieces, isSquareAttacked ( 5, 6 ) Red pieces )
            ]
        , describe "checkmate / stalemate (loss either way in Xiangqi)"
            [ test "a lone general with both palace exits covered has lost" <|
                \_ ->
                    -- Black's general sits at (3,0), a palace corner, whose only
                    -- two pseudo-legal destinations are (4,0) and (3,1). A Red
                    -- chariot on file 4 covers (4,0); a Red chariot on rank 1
                    -- covers (3,1). Neither chariot attacks (3,0) itself, so
                    -- this is stalemate rather than checkmate -- deliberately,
                    -- to confirm isGameOver treats both as a loss.
                    let
                        pieces =
                            [ ( ( 3, 0 ), Piece Black General )
                            , ( ( 4, 9 ), Piece Red Chariot )
                            , ( ( 8, 1 ), Piece Red Chariot )
                            ]
                    in
                    Expect.equal ( False, True ) ( inCheck Black pieces, isGameOver Black pieces )
            , test "a side with any legal move has not lost" <|
                \_ -> Expect.equal False (isGameOver Red initialPieces)
            , test "capturing a general ends the game immediately" <|
                \_ ->
                    let
                        pieces =
                            [ ( ( 4, 9 ), Piece Red General )
                            , ( ( 4, 0 ), Piece Red Chariot )
                            ]
                    in
                    Expect.equal True (isGameOver Black pieces)
            ]
        , describe "basic move legality sanity checks"
            [ test "start position has exactly 44 legal moves for Red" <|
                \_ -> Expect.equal 44 (List.length (generateLegalMoves Red initialPieces))
            , test "a general can capture the opposing general on an open file" <|
                \_ ->
                    let
                        pieces =
                            [ ( ( 4, 0 ), Piece Black General )
                            , ( ( 4, 9 ), Piece Red General )
                            ]
                    in
                    generateLegalMoves Red pieces
                        |> List.member ( ( 4, 9 ), ( 4, 0 ) )
                        |> Expect.equal True
            , test "a move is never legal onto a square occupied by your own piece" <|
                \_ ->
                    generateLegalMoves Red initialPieces
                        |> List.any (\( _, to ) -> List.member to (List.map Tuple.first initialPieces) && isOwnPieceAt to initialPieces Red)
                        |> Expect.equal False
            ]
        , describe "play against the agent"
            [ test "the player can take Red and their move requests a Black reply" <|
                \_ ->
                    let
                        ( loading, startEffect ) =
                            Xiangqi.update (Xiangqi.StartAgentGame Red) Xiangqi.init

                        ( ready, loadEffect ) =
                            Xiangqi.update (Xiangqi.EngineEventReceived (engineLoaded "cpu")) loading

                        ( selected, selectEffect ) =
                            Xiangqi.update (Xiangqi.Select ( 0, 6 )) ready

                        ( afterMove, moveEffect ) =
                            Xiangqi.update (Xiangqi.Select ( 0, 5 )) selected
                    in
                    case ( startEffect, loadEffect, selectEffect ) of
                        ( Xiangqi.LoadEngineEffect, Xiangqi.NoEffect, Xiangqi.NoEffect ) ->
                            case moveEffect of
                                Xiangqi.RequestMoveEffect _ fen legalMoves ->
                                    Expect.all
                                        [ \_ -> Expect.equal Black afterMove.turn
                                        , \_ -> Expect.equal True (String.contains " b " fen)
                                        , \_ -> Expect.equal False (List.isEmpty legalMoves)
                                        ]
                                        ()

                                _ ->
                                    Expect.fail "expected the human move to request the agent's Black reply"

                        _ ->
                            Expect.fail "expected the human move to request the agent's Black reply"
            , test "the player can take Black and the Red agent opens" <|
                \_ ->
                    let
                        ( loading, startEffect ) =
                            Xiangqi.update (Xiangqi.StartAgentGame Black) Xiangqi.init

                        ( thinking, loadEffect ) =
                            Xiangqi.update (Xiangqi.EngineEventReceived (engineLoaded "cpu")) loading
                    in
                    case ( startEffect, loadEffect ) of
                        ( Xiangqi.LoadEngineEffect, Xiangqi.RequestMoveEffect _ fen legalMoves ) ->
                            Expect.all
                                [ \_ -> Expect.equal Red thinking.turn
                                , \_ -> Expect.equal True (String.contains " w " fen)
                                , \_ -> Expect.equal 44 (List.length legalMoves)
                                ]
                                ()

                        _ ->
                            Expect.fail "expected the Red agent to request the opening move"
            , test "the Red agent's returned opening move is played on the board" <|
                \_ ->
                    let
                        ( loading, _ ) =
                            Xiangqi.update (Xiangqi.StartAgentGame Black) Xiangqi.init

                        ( thinking, loadEffect ) =
                            Xiangqi.update (Xiangqi.EngineEventReceived (engineLoaded "cpu")) loading
                    in
                    case loadEffect of
                        Xiangqi.RequestMoveEffect requestId _ _ ->
                            let
                                ( afterAgentMove, responseEffect ) =
                                    Xiangqi.update
                                        (Xiangqi.EngineEventReceived (engineMove requestId 27 36))
                                        thinking
                            in
                            Expect.all
                                [ \_ -> Expect.equal Black afterAgentMove.turn
                                , \_ -> Expect.equal True (hasPieceAt Red Soldier ( 0, 5 ) afterAgentMove.pieces)
                                , \_ -> Expect.equal False (hasPieceAt Red Soldier ( 0, 6 ) afterAgentMove.pieces)
                                , \_ -> Expect.equal Xiangqi.NoEffect responseEffect
                                ]
                                ()

                        _ ->
                            Expect.fail "expected an opening move request"
            , test "the Black agent's returned reply is played on the board" <|
                \_ ->
                    let
                        ( loading, _ ) =
                            Xiangqi.update (Xiangqi.StartAgentGame Red) Xiangqi.init

                        ( ready, _ ) =
                            Xiangqi.update (Xiangqi.EngineEventReceived (engineLoaded "cpu")) loading

                        ( selected, _ ) =
                            Xiangqi.update (Xiangqi.Select ( 0, 6 )) ready

                        ( thinking, moveEffect ) =
                            Xiangqi.update (Xiangqi.Select ( 0, 5 )) selected
                    in
                    case moveEffect of
                        Xiangqi.RequestMoveEffect requestId _ _ ->
                            let
                                ( afterAgentMove, _ ) =
                                    Xiangqi.update
                                        (Xiangqi.EngineEventReceived (engineMove requestId 54 45))
                                        thinking
                            in
                            Expect.all
                                [ \_ -> Expect.equal Red afterAgentMove.turn
                                , \_ -> Expect.equal True (hasPieceAt Black Soldier ( 0, 4 ) afterAgentMove.pieces)
                                , \_ -> Expect.equal False (hasPieceAt Black Soldier ( 0, 3 ) afterAgentMove.pieces)
                                ]
                                ()

                        _ ->
                            Expect.fail "expected a Black reply request"
            , test "a stale agent response cannot move the current position" <|
                \_ ->
                    let
                        ( loading, _ ) =
                            Xiangqi.update (Xiangqi.StartAgentGame Black) Xiangqi.init

                        ( thinking, loadEffect ) =
                            Xiangqi.update (Xiangqi.EngineEventReceived (engineLoaded "cpu")) loading
                    in
                    case loadEffect of
                        Xiangqi.RequestMoveEffect requestId _ _ ->
                            let
                                ( unchanged, responseEffect ) =
                                    Xiangqi.update
                                        (Xiangqi.EngineEventReceived (engineMove (requestId + 1) 27 36))
                                        thinking
                            in
                            Expect.all
                                [ \_ -> Expect.equal Red unchanged.turn
                                , \_ -> Expect.equal True (hasPieceAt Red Soldier ( 0, 6 ) unchanged.pieces)
                                , \_ -> Expect.equal False (hasPieceAt Red Soldier ( 0, 5 ) unchanged.pieces)
                                , \_ -> Expect.equal Xiangqi.NoEffect responseEffect
                                ]
                                ()

                        _ ->
                            Expect.fail "expected an opening move request"
            , test "an outdated cached worker is rejected before it can move" <|
                \_ ->
                    let
                        ( loading, _ ) =
                            Xiangqi.update (Xiangqi.StartAgentGame Black) Xiangqi.init

                        ( rejected, effect ) =
                            Xiangqi.update (Xiangqi.EngineEventReceived (engineLoadedWithProtocol 1)) loading
                    in
                    Expect.all
                        [ \_ -> Expect.equal Red rejected.turn
                        , \_ -> Expect.equal initialPieces rejected.pieces
                        , \_ -> Expect.equal Xiangqi.UnloadEngineEffect effect
                        ]
                        ()
            , test "suspending the page terminates pending engine work" <|
                \_ ->
                    let
                        ( loading, _ ) =
                            Xiangqi.update (Xiangqi.StartAgentGame Black) Xiangqi.init

                        ( thinking, _ ) =
                            Xiangqi.update (Xiangqi.EngineEventReceived (engineLoaded "cpu")) loading

                        ( suspended, effect ) =
                            Xiangqi.update Xiangqi.SuspendEngine thinking

                        ( afterStaleMove, staleEffect ) =
                            Xiangqi.update (Xiangqi.EngineEventReceived (engineMove 1 27 36)) suspended
                    in
                    Expect.all
                        [ \_ -> Expect.equal Xiangqi.UnloadEngineEffect effect
                        , \_ -> Expect.equal Red afterStaleMove.turn
                        , \_ -> Expect.equal initialPieces afterStaleMove.pieces
                        , \_ -> Expect.equal Xiangqi.NoEffect staleEffect
                        ]
                        ()
            ]
        ]


isOwnPieceAt : ( Int, Int ) -> List ( ( Int, Int ), Piece ) -> Side -> Bool
isOwnPieceAt position pieces side =
    pieces
        |> List.any (\( p, piece ) -> p == position && piece.side == side)


hasPieceAt : Side -> PieceKind -> ( Int, Int ) -> List ( ( Int, Int ), Piece ) -> Bool
hasPieceAt side kind position pieces =
    pieces
        |> List.any (\( candidate, piece ) -> candidate == position && piece.side == side && piece.kind == kind)


engineLoaded : String -> Encode.Value
engineLoaded backend =
    engineLoadedEvent backend 2


engineLoadedWithProtocol : Int -> Encode.Value
engineLoadedWithProtocol protocol =
    engineLoadedEvent "cpu" protocol


engineLoadedEvent : String -> Int -> Encode.Value
engineLoadedEvent backend protocol =
    Encode.object
        [ ( "type", Encode.string "loaded" )
        , ( "backend", Encode.string backend )
        , ( "protocol", Encode.int protocol )
        ]


engineMove : Int -> Int -> Int -> Encode.Value
engineMove requestId from to =
    Encode.object
        [ ( "type", Encode.string "move" )
        , ( "requestId", Encode.int requestId )
        , ( "from", Encode.int from )
        , ( "to", Encode.int to )
        , ( "value", Encode.float 0.25 )
        ]
