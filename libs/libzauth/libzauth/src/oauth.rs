use base64::Engine;
use jwt_simple::prelude::*;

#[derive(Debug, serde::Deserialize, serde::Serialize)]
pub struct OAuthToken {
    pub scope: String,
}

pub fn verify_oauth_token(jwk: &str, token: &str, scope: &str) -> Result<String, OauthError> {
    let jwk = serde_json::from_str::<Jwk>(jwk)?;
    let key = try_from_jwk(&jwk)?;
    let options = VerificationOptions {
        time_tolerance: Some(Duration::from_secs(1)),
        ..Default::default()
    };
    let claims = key.verify_token::<OAuthToken>(token, Some(options))?;
    let subject = claims.subject.ok_or(OauthError::InvalidJwtNoSubject)?;
    verify_scope(&claims.custom.scope, scope)?;
    Ok(subject)
}

fn verify_scope(scope: &str, required_scope: &str) -> Result<(), OauthError> {
    let valid = scope.split_whitespace().any(|s| s == required_scope);
    if !valid {
        return Err(OauthError::InvalidScope);
    }
    Ok(())
}

fn try_from_jwk(jwk: &Jwk) -> Result<Ed25519PublicKey, OauthError> {
    Ok(match &jwk.algorithm {
        AlgorithmParameters::OctetKeyPair(p) => {
            let x = base64::prelude::BASE64_URL_SAFE_NO_PAD.decode(&p.x)?;
            Ed25519PublicKey::from_bytes(&x)?
        }
        _ => return Err(OauthError::InvalidJwk),
    })
}

#[derive(Debug, thiserror::Error)]
pub enum OauthError {
    /// Json error
    #[error(transparent)]
    JsonError(#[from] serde_json::Error),
    /// JWT error from jwt-simple crate
    #[error(transparent)]
    JwtSimpleError(#[from] jwt_simple::Error),
    /// Base64 decoding error
    #[error(transparent)]
    Base64DecodeError(#[from] base64::DecodeError),
    /// Invalid JWK
    #[error("invalid jwk")]
    InvalidJwk,
    /// Invalid JWT missing subject
    #[error("missing subject")]
    InvalidJwtNoSubject,
    /// Invalid scope
    #[error("invalid scope")]
    InvalidScope,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_verify_oauth_token() {
        let uid = "842ddbc8-56ec-408d-9fa8-7a8c37ad22a7";
        let key = Ed25519KeyPair::generate();
        let jwk = mk_jwk(key.public_key());
        let token = Claims::with_custom_claims(
            OAuthToken {
                scope: "foo test bar".to_string(),
            },
            Duration::from_secs(3600),
        )
        .with_subject(uid);
        let jwt = key.sign::<OAuthToken>(token).unwrap();
        let subject =
            verify_oauth_token(&serde_json::to_string(&jwk).unwrap(), &jwt, "test").unwrap();
        assert_eq!(&subject, uid);
    }
    fn mk_jwk(key: Ed25519PublicKey) -> Jwk {
        let x = base64::prelude::BASE64_URL_SAFE_NO_PAD.encode(&key.to_bytes());
        Jwk {
            common: CommonParameters::default(),
            algorithm: AlgorithmParameters::OctetKeyPair(OctetKeyPairParameters {
                key_type: OctetKeyPairType::OctetKeyPair,
                curve: EdwardCurve::Ed25519,
                x,
            }),
        }
    }
}
