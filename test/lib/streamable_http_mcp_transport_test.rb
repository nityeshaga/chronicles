require "test_helper"

class StreamableHttpMcpTransportTest < ActiveSupport::TestCase
  # The buffer that carries a JSON-RPC response from send_message back to the POST
  # handler lives on the single shared middleware instance. It must be thread-local,
  # or two concurrent POSTs on different Puma threads read each other's responses.
  test "response buffer is thread-local so concurrent requests never cross-contaminate" do
    transport = StreamableHttpMcpTransport.new(->(_env) { [ 200, {}, [] ] }, Object.new, session_store: Object.new)

    failures = Concurrent::Array.new
    ready = Concurrent::CountDownLatch.new(2)

    threads = %w[ A B ].map do |tag|
      Thread.new do
        ready.count_down
        ready.wait(1)

        300.times do |i|
          id = "#{tag}-#{i}"
          transport.send_message({ jsonrpc: "2.0", id: id, result: {} })
          Thread.pass
          echoed = JSON.parse(Thread.current[:mcp_response_buffer])
          failures << "#{id} read back #{echoed["id"]}" unless echoed["id"] == id
        end
      end
    end
    threads.each(&:join)

    assert_empty failures, "buffer cross-contamination: #{failures.first(5).join(", ")}"
  end
end
