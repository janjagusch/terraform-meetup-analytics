# terraform-meetup-analytics

Setting up an analytics pipeline for Meetup on Google Cloud. 🥳

## Getting started

### Requirements

What you need to get started:

* An approved [Meetup OAuth consumer](https://secure.meetup.com/meetup_api/oauth_consumers/)
* A fresh Google Cloud project
* [Terraform](https://github.com/hashicorp/terraform) v0.12 or higher

### Meetup authenticiation

Before you can automatically query to Meetup API, you need to request an initial access token and store it in your projects token bucket/blob. The authentication process is documented [here](https://www.meetup.com/meetup_api/auth/#oauth2). However, [meetup-token-manager](https://github.com/janjagusch/meetup-token-manager) provides an authentication convenience function:

```python
import os

from meetup.token_manager.utils import request_token
from meetup.token_manager import TokenCacheGCS

CLIENT_ID = os.environ["CLIENT_ID"] # the id of your Meetup OAuth consumer
CLIENT_SECRET = os.environ["CLIENT_SECRET"] # the secret of your Meetup OAuth consumer
REDIRECT_URI = os.environ["REDIRECT_URI"] # th redirect uri of your Meetup OAuth consumer

BUCKET_NAME = os.environ["BUCKET_NAME"] # name of the GCS bucket where the token will be stored
BLOB_NAME = os.environ["BLOB_NAME"] # name of the GCS blob where the token will be stored

token = request_token(CLIENT_ID, CLIENT_SECRET, REDIRECT_URI) # follow the instructions

cache = TokenCacheGCS(BUCKET_NAME, BLOB_NAME)

cache._store_token(token.to_dict()) # stores the token in GCP
```

Now everything is set up! 🌈
