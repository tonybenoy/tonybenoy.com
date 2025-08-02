import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from fastapi import APIRouter, Request, Form, HTTPException
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.responses import RedirectResponse

from app.utils import templates
from app.config import get_settings

# Use the same limiter instance as main app
limiter = Limiter(key_func=get_remote_address)

logger = logging.getLogger(__name__)
home = APIRouter()


@home.get("/")
@home.get("/index")
@limiter.limit("30/minute")
async def index(request: Request):
    """Home page with rate limiting."""
    return templates.TemplateResponse(
        request, "index.html", {"title": "Tony", "active_page": "home"}
    )


@home.get("/test")
async def test():
    return {"result": "It works!"}


@home.get("/favicon.ico")
async def favicon():
    return RedirectResponse(url="/static/img/favicon.ico")


@home.get("/myssh")
async def myssh():
    return RedirectResponse(url="/static/files/tony.sh")


@home.get("/client_ip")
@limiter.limit("10/minute")
async def get_my_ip(request: Request):
    """Get client IP and user agent information."""
    client_ip = request.client.host if request.client else "unknown"
    client_ua = request.headers.get("User-Agent")
    forwarded_for = request.headers.get("X-Forwarded-For")
    real_ip = request.headers.get("X-Real-IP")

    return {
        "ip": client_ip,
        "user_agent": client_ua,
        "x_forwarded_for": forwarded_for,
        "x_real_ip": real_ip,
    }


@home.get("/health")
async def health_check():
    """Health check endpoint for monitoring."""
    return {
        "status": "healthy",
        "timestamp": "2025-01-01T00:00:00Z",  # Dynamic in real implementation
        "version": "2.0.0",
    }


@home.get("/metrics")
@limiter.limit("5/minute")
async def metrics(request: Request):
    """Basic metrics endpoint."""
    import time

    try:
        import psutil
    except ImportError:
        return {"status": "ok", "message": "Detailed metrics not available"}

    return {
        "uptime": time.time(),  # Would track actual uptime
        "memory_usage": psutil.virtual_memory().percent,
        "cpu_usage": psutil.cpu_percent(),
        "disk_usage": psutil.disk_usage("/").percent,
        "requests_total": "N/A",  # Would implement proper metrics
        "status": "ok",
    }


@home.get("/contact")
@limiter.limit("30/minute")
async def contact_page(request: Request):
    """Contact page with form."""
    return templates.TemplateResponse(
        request, "contact.html", {"title": "Contact - Tony", "active_page": "contact"}
    )


@home.post("/contact")
@limiter.limit("5/minute")
async def contact_submit(
    request: Request,
    name: str = Form(..., min_length=2, max_length=100),
    email: str = Form(..., min_length=5, max_length=255),
    subject: str = Form(..., min_length=5, max_length=200),
    message: str = Form(..., min_length=10, max_length=2000)
):
    """Handle contact form submission."""
    settings = get_settings()
    
    try:
        # Create email message
        msg = MIMEMultipart()
        msg['From'] = settings.smtp_username if hasattr(settings, 'smtp_username') else "noreply@tonybenoy.com"
        msg['To'] = settings.contact_email if hasattr(settings, 'contact_email') else "me@tonybenoy.com"
        msg['Subject'] = f"Contact Form: {subject}"
        
        # Email body
        body = f"""
New contact form submission:

From: {name} <{email}>
Subject: {subject}

Message:
{message}

---
Sent from tonybenoy.com contact form
Client IP: {request.client.host if request.client else 'unknown'}
User Agent: {request.headers.get('User-Agent', 'unknown')}
        """
        
        msg.attach(MIMEText(body, 'plain'))
        
        # Send email (only if SMTP is configured)
        if hasattr(settings, 'smtp_server') and settings.smtp_server:
            try:
                server = smtplib.SMTP(settings.smtp_server, settings.smtp_port if hasattr(settings, 'smtp_port') else 587)
                server.starttls()
                if hasattr(settings, 'smtp_username') and hasattr(settings, 'smtp_password'):
                    server.login(settings.smtp_username, settings.smtp_password)
                
                server.send_message(msg)
                server.quit()
                
                logger.info(f"Contact form email sent from {email}")
                success_message = "Thank you! Your message has been sent successfully."
            except Exception as e:
                logger.error(f"Failed to send email: {e}")
                success_message = "Thank you! Your message has been received (email delivery pending)."
        else:
            # Log the message if no SMTP configured
            logger.info(f"Contact form submission: {name} <{email}> - {subject}")
            success_message = "Thank you! Your message has been received."
        
        return templates.TemplateResponse(
            request, 
            "contact.html", 
            {
                "title": "Contact - Tony", 
                "active_page": "contact",
                "success_message": success_message
            }
        )
        
    except Exception as e:
        logger.error(f"Contact form error: {e}")
        return templates.TemplateResponse(
            request,
            "contact.html",
            {
                "title": "Contact - Tony",
                "active_page": "contact", 
                "error_message": "Sorry, there was an error sending your message. Please try again."
            }
        )
