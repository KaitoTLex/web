module Test.Generated.Main28074385 exposing (main)

import XiangqiTest

import Test.Reporter.Reporter exposing (Report(..))
import Console.Text exposing (UseColor(..))
import Test.Runner.Node
import Test

main : Test.Runner.Node.TestProgram
main =
    [     Test.describe "XiangqiTest" [XiangqiTest.suite] ]
        |> Test.concat
        |> Test.Runner.Node.run { runs = Nothing, report = (ConsoleReport UseColor), seed = 45297327314496, processes = 16, paths = ["/home/kaitotlex/Source/web/tests/XiangqiTest.elm"]}