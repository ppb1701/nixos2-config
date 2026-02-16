{
  services.nginx.virtualHosts = {

      "search.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8888";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          '';
        };
      };

      "links.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8230";  # Linkwarden default port
        };
      };

      "cloud.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8280";
          proxyWebsockets = true;
        };
      };

      "ntfy.home" = {
        locations."/" = {
          proxyPass = "http://localhost:2586";
          proxyWebsockets = true;
        };
      };

      "alertmanager.home" = {
        locations."/" = {
          proxyPass = "http://localhost:9093";
        };
      };

      "grafana.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };

      "prometheus.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:9090";
        };
      };

      "adguard.home" = {
        default = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
        };
      };

      "syncthing.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8384";
          proxyWebsockets = true;
        };
      };

      "notes.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:5000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
       "git.home" = {
        # forceSSL = true; # Set to true if you have ACME/Certs setup
        # enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:3300"; # Matches the Gitea HTTP_PORT
          proxyWebsockets = true; # Crucial for Gitea's actions/features

          extraConfig = ''
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
      "ntfy2.home" = {
        locations."/" = {
          proxyPass = "http://localhost:2586";
          proxyWebsockets = true;
        };
      };

      "alertmanager2.home" = {
        locations."/" = {
          proxyPass = "http://localhost:9093";
        };
      };

      "grafana2.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };

      "prometheus2.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:9090";
        };
      };

      "adguard2.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
        };
      };

       "home.home" = {
      # listen = [{ addr = secrets.tailscaleIP; port = 80; }];
        locations."/" = {
                proxyPass = "http://127.0.0.1:8582";
                proxyWebsockets = true;
        };
      };

       "home2.home" = {
      # listen = [{ addr = secrets.tailscaleIP; port = 80; }];
        locations."/" = {
                proxyPass = "http://127.0.0.1:8582";
                proxyWebsockets = true;
        };
      };

      "syncthing2.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8384";
          proxyWebsockets = true;
        };
      };

      "notes2.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:5000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };

}
