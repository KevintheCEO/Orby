$ErrorActionPreference='Stop'
# Load only the pure journal reader, avoiding production feed worker initialization.
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Pet-Feed.ps1'))
$end=$source.IndexOf("`n'@")
. ([scriptblock]::Create($source.Substring(0,$end+4)))
$dir=Join-Path ([IO.Path]::GetTempPath()) ('orby-question-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($dir)
$journal=Join-Path $dir 'test.jsonl'
$clock=[datetime]::UtcNow
function Add-Event($type,$payload){$script:clock=$script:clock.AddMilliseconds(10);$orderedPayload=[ordered]@{type=$payload.type};foreach($key in $payload.Keys){if($key -ne 'type'){$orderedPayload[$key]=$payload[$key]}};$line=[ordered]@{timestamp=$script:clock.ToString('o');type=$type;payload=$orderedPayload}|ConvertTo-Json -Depth 15 -Compress;[IO.File]::AppendAllText($journal,$line+"`n",[Text.UTF8Encoding]::new($false))}
function Read-Task {[OrbitPetFeed]::Read([OrbitPetTask]@{Id='fixture';Title='Question fixture';Path=$journal})}
function Check($ok,$message){if(-not $ok){throw $message};$script:checks++}
Add-Event 'event_msg' @{type='task_started';turn_id='turn-one'}
Add-Event 'response_item' @{type='function_call';name='functions.request_user_input_async';call_id='call_question';arguments='{}'}
Check ((Read-Task).State -eq 'attention') 'Async question did not request attention'
Add-Event 'response_item' @{type='function_call_output';call_id='call_question';output='{"accepted":true}'}
Check ((Read-Task).State -eq 'attention') 'Delivery acknowledgment cleared unanswered question'
Add-Event 'response_item' @{type='function_call';name='functions.exec';call_id='call_other';arguments='{}'}
Add-Event 'response_item' @{type='function_call_output';call_id='call_other';output='done'}
Check ((Read-Task).State -eq 'attention') 'Parallel work hid pending answer'
Add-Event 'response_item' @{type='message';role='user';content=@(@{type='input_text';text='<send_user_message_question_reply>call_different</send_user_message_question_reply>'})}
Check ((Read-Task).State -eq 'attention') 'Different question reply resumed this request'
Add-Event 'response_item' @{type='message';role='user';content=@(@{type='input_text';text='<send_user_message_question_reply>call_question</send_user_message_question_reply>'})}
Check ((Read-Task).State -eq 'working') 'Matching human reply did not resume work'
Add-Event 'response_item' @{type='function_call';name='functions.request_user_input';call_id='call_sync';arguments='{}'}
Add-Event 'response_item' @{type='function_call_output';call_id='call_sync';output='{"answers":{"choice":"yes"}}'}
Check ((Read-Task).State -eq 'working') 'Synchronous answer no longer resumes'
Add-Event 'response_item' @{type='function_call';name='functions.request_user_input_async';call_id='call_failed';arguments='{}'}
Add-Event 'response_item' @{type='function_call_output';call_id='call_failed';output='{"accepted":false}'}
Check ((Read-Task).State -eq 'working') 'Failed async delivery left a phantom question'
Add-Event 'response_item' @{type='function_call';name='functions.request_user_input_async';arguments=('x'*1200);call_id='call_long_question'}
Add-Event 'response_item' @{type='function_call_output';call_id='call_long_question';output='{"accepted":true}'}
Check ((Read-Task).PendingCall -eq 'call_long_question' -and (Read-Task).State -eq 'attention') 'Long question lost its request identity'
Add-Event 'event_msg' @{type='user_message';message='<send_user_message_question_reply>call_long_question</send_user_message_question_reply>'}
Check ((Read-Task).State -eq 'working') 'Event-message answer did not resume the matching question'
Add-Event 'event_msg' @{type='task_complete';turn_id='turn-one'}
Check ((Read-Task).State -eq 'success') 'Terminal state lost'
'PASS: '+$script:checks+' async question lifecycle checks'
