-module(jsonformat_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-compile(export_all).

-define(assertJSONEqual(Expected, Actual),
    ?assertEqual(thoas:decode(Expected), thoas:decode(Actual))
).

all() -> [format_test, format_funs_test, key_mapping_test, list_format_test, meta_without_test, meta_with_test, newline_test].

format_test(_) ->
  ?assertJSONEqual(
      <<"{\"level\":\"alert\",\"text\":\"derp\"}">>,
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{}}, #{})
  ),
  ?assertJSONEqual(
      <<"{\"herp\":\"derp\",\"level\":\"alert\"}">>,
      jsonformat:format(#{level => alert, msg => {report, #{herp => derp}}, meta => #{}}, #{})
  ).

format_funs_test(_) ->
  Config1 = #{
      format_funs => #{
          time => fun(Epoch) -> Epoch + 1 end,
          level => fun(alert) -> info end
      }
  },
  ?assertJSONEqual(
      <<"{\"level\":\"info\",\"text\":\"derp\",\"time\":2}">>,
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{time => 1}}, Config1)
  ),

  Config2 = #{
      format_funs => #{
          time => fun(Epoch) -> Epoch + 1 end,
          foobar => fun(alert) -> info end
      }
  },
  ?assertJSONEqual(
      <<"{\"level\":\"alert\",\"text\":\"derp\",\"time\":2}">>,
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{time => 1}}, Config2)
  ).

key_mapping_test(_) ->
  Config1 = #{
      key_mapping => #{
          level => lvl,
          text => message
      }
  },
  ?assertJSONEqual(
      <<"{\"lvl\":\"alert\",\"message\":\"derp\"}">>,
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{}}, Config1)
  ),

  Config2 = #{
      key_mapping => #{
          level => lvl,
          text => level
      }
  },
  ?assertJSONEqual(
      <<"{\"level\":\"derp\",\"lvl\":\"alert\"}">>,
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{}}, Config2)
  ),

  Config3 = #{
      key_mapping => #{
          level => lvl,
          foobar => level
      }
  },
  ?assertJSONEqual(
      <<"{\"lvl\":\"alert\",\"text\":\"derp\"}">>,
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{}}, Config3)
  ),

  Config4 = #{
      key_mapping => #{time => timestamp},
      format_funs => #{timestamp => fun(T) -> T + 1 end}
  },
  ?assertJSONEqual(
      <<"{\"level\":\"alert\",\"text\":\"derp\",\"timestamp\":2}">>,
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{time => 1}}, Config4)
  ).

list_format_test(_) ->
  ErrorReport =
      #{
          level => error,
          meta => #{time => 1},
          msg => {report, #{report => [{hej, "hopp"}]}}
      },
  ?assertJSONEqual(
      <<"{\"level\":\"error\",\"report\":\"[{hej,\\\"hopp\\\"}]\",\"time\":1}">>,
      jsonformat:format(ErrorReport, #{})
  ).

meta_without_test(_) ->
  Error = #{
      level => info,
      msg => {report, #{answer => 42}},
      meta => #{secret => xyz}
  },
  ?assertEqual(
      #{
          <<"answer">> => 42,
          <<"level">> => <<"info">>,
          <<"secret">> => <<"xyz">>
      },
      json_decode(jsonformat:format(Error, #{}))
  ),
  Config2 = #{meta_without => [secret]},
  ?assertEqual(
      #{
          <<"answer">> => 42,
          <<"level">> => <<"info">>
      },
      json_decode(jsonformat:format(Error, Config2))
  ),
  ok.

meta_with_test(_) ->
  Error = #{
      level => info,
      msg => {report, #{answer => 42}},
      meta => #{secret => xyz}
  },
  ?assertEqual(
      #{
          <<"answer">> => 42,
          <<"level">> => <<"info">>,
          <<"secret">> => <<"xyz">>
      },
      json_decode(jsonformat:format(Error, #{}))
  ),
  Config2 = #{meta_with => [level]},
  ?assertEqual(
      #{
          <<"answer">> => 42,
          <<"level">> => <<"info">>
      },
      json_decode(jsonformat:format(Error, Config2))
  ),
  ok.

newline_test(_) ->
  ConfigDefault = #{new_line => true},
  ?assertEqual(
      %[<<"{\"level\":\"alert\",\"text\":\"derp\"}">>, <<"\n">>],
      [[<<"{\"">>,[[]|<<"level">>],<<"\":">>,[34,[[]|<<"alert">>],34],<<",\"">>,[[]|<<"text">>],<<"\":">>,[34,[[]|<<"derp">>],34],125],<<"\n">>],
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{}}, ConfigDefault)
  ),
  ConfigCRLF = #{
      new_line_type => crlf,
      new_line => true
  },
  ?assertEqual(
      %[<<"{\"level\":\"alert\",\"text\":\"derp\"}">>, <<"\r\n">>],
      [[<<"{\"">>,[[]|<<"level">>],<<"\":">>,[34,[[]|<<"alert">>],34],<<",\"">>,[[]|<<"text">>],<<"\":">>,[34,[[]|<<"derp">>],34],125],<<"\r\n">>],
      jsonformat:format(#{level => alert, msg => {string, "derp"}, meta => #{}}, ConfigCRLF)
  ).

json_decode(JsonString) ->
  {ok, JsonMap} = thoas:decode(JsonString),
  JsonMap.