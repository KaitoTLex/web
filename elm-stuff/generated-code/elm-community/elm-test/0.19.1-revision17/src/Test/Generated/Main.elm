module Test.Generated.Main exposing (main)

import XiangqiTest

import Test.Reporter.Reporter exposing (Report(..))
import Console.Text exposing (UseColor(..))
import Test.Runner.Node
import Test

main : Test.Runner.Node.TestProgram
main =
    Test.Runner.Node.run
        { runs = 100
        , report = ConsoleReport Monochrome
        , seed = 172357781863377
        , processes = 16
        , globs =
            []
        , paths =
            [ "/home/kaitotlex/Source/web/tests/XiangqiTest.elm"
            ]
        }
        [ ( "XiangqiTest"
          , [ Test.Runner.Node.check XiangqiTest.suite
            ]
          )
        ]