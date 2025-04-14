# Define constants for configuration values
def get_config(env):
        if env == 'prod':
                return {
                        'client_id': "",
                        'client_secret': "",
                        'token_url': "",
                        'scope': "",
                        'audience': "",
                        'base_url': "",
                        'log_dir': r'',
                        'csv_path': r''
                }
        elif env == 'dev':
                return {
                        'client_id': "",
                        'client_secret': "",
                        'token_url': "",
                        'scope': "",
                        'audience': "",
                        'base_url': "",
                        'log_dir': r'',
                        'csv_path': r''
                }
