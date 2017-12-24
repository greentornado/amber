require "watcher"

module Amber::Support
  # Used by `Amber::Pipe::Reload`
  #
  # Allow clients browser reloading using WebSockets and file watchers.
  struct ClientReload
    WEBSOCKET_PATH = rand(0x10000000).to_s(36)

    SESSIONS = [] of HTTP::WebSocket

    def initialize
      create_reload_server
      spawn watch_files
    end

    private def create_reload_server
      Amber::WebSockets::Server::Handler.new "/#{WEBSOCKET_PATH}" do |session|
        SESSIONS << session
        session.on_close do
          SESSIONS.delete session
        end
      end
    end

    private def reload_clients(msg)
      SESSIONS.each do |session|
        session.@ws.send msg
      end
    end

    private def watch_files
      puts "🔃  Your ClientBot is vigilant. beep-boop..."
      watch(["public/**/*"]) do |event|
        event.on_change do |files|
          files.each do |file, timestamp|
            puts "🔃  watching file: ./#{file}"
            case file
            when .ends_with? ".css"
              reload_clients(msg: "refreshcss")
            else
              reload_clients(msg: "reload")
            end
          end
        end
      end
    end

    # Code from https://github.com/tapio/live-server/blob/master/injected.html
    INJECTED_CODE = <<-HTML
    <!-- Code injected by live-server -->
    <script type="text/javascript">
      // <![CDATA[  <-- For SVG support
      if ('WebSocket' in window) {
        (function() {
          function refreshCSS() {
            console.log('Reloading CSS...');
            var sheets = [].slice.call(document.getElementsByTagName('link'));
            var head = document.getElementsByTagName('head')[0];
            for (var i = 0; i < sheets.length; ++i) {
              var elem = sheets[i];
              head.removeChild(elem);
              var rel = elem.rel;
              if (elem.href && typeof rel != 'string' || rel.length == 0 || rel.toLowerCase() == 'stylesheet') {
                var url = elem.href.replace(/(&|\\?)_cacheOverride=\\d+/, '');
                elem.href = url + (url.indexOf('?') >= 0 ? '&' : '?') + '_cacheOverride=' + (new Date().valueOf());
              }
              head.appendChild(elem);
            }
          }
          var protocol = window.location.protocol === 'http:' ? 'ws://' : 'wss://';
          var address = protocol + window.location.host + '/#{WEBSOCKET_PATH}';
          var socket = new WebSocket(address);
          socket.onmessage = function(msg) {
            console.log(msg);
            if (msg.data == 'reload') {
              window.location.reload();
            } else if (msg.data == 'refreshcss') {
              refreshCSS();
            }
          };
          socket.onclose = function() {
            console.log('Conection closed!');
            setTimeout(function() {
                window.location.reload();
            }, 1000);
          }
          console.log('Live reload enabled.');
        })();
      }
      // ]]>
    </script>\n
    HTML
  end
end
