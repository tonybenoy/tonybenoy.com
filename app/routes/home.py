import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from fastapi import APIRouter, Form, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.responses import RedirectResponse

from app.config import get_settings
from app.utils import templates

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


@home.get("/timeline")
@limiter.limit("30/minute")
async def timeline_page(request: Request):
    """Timeline page with work experience and education."""
    # Work experience data from CV
    work_experience = [
        {
            "title": "Chief Technology Officer",
            "company": "Proffyhub OÜ",
            "period": "Jul. 2024 – Present",
            "location": "Tallinn, Estonia",
            "company_url": "https://proffy.ee",
            "logo": "/static/img/logos/proffyhub.png",
            "description": (
                "Leading technical strategy and product development for Proffy.ee, "
                "Estonia's flexible work platform. Building scalable job marketplace "
                "connecting employers with workers seeking part-time and gig "
                "opportunities, while developing features for schedule flexibility "
                "and skill development."
            ),
            "technologies": [
                "TypeScript",
                "NestJS",
                "PostgreSQL",
                "Next.js",
                "React",
                "Technical Leadership",
                "Marketplace Platforms",
                "Product Strategy",
                "AWS Cloud",
            ],
            "type": "leadership",
            "icon": "fas fa-crown",
        },
        {
            "title": "Founder",
            "company": "Sunyata OÜ",
            "period": "Nov. 2022 – Present",
            "location": "Tallinn, Estonia",
            "company_url": "https://github.com/Sunyata-OU",
            "logo": "/static/img/logos/sunyata.png",
            "description": (
                "Founded and operating an independent software development company "
                "in Estonia. Focusing on cutting-edge technology solutions and "
                "open-source contributions while building sustainable business "
                "practices."
            ),
            "technologies": [
                "Full-Stack Engineering",
                "Cloud Architecture",
                "DevOps & CI/CD",
                "Open Source Contributions",
                "Team Leadership",
                "Business Strategy",
            ],
            "type": "entrepreneurship",
            "icon": "fas fa-rocket",
        },
        {
            "title": "Senior Software Engineer",
            "company": "Merkle Science",
            "period": "Aug. 2021 – Apr. 2022",
            "location": "Bengaluru, India",
            "company_url": "https://merklescience.com",
            "logo": "/static/img/logos/merkle-science.png",
            "description": (
                "Developed blockchain analytics and cryptocurrency compliance "
                "solutions for financial institutions and government agencies. "
                "Built predictive risk monitoring systems and transaction analysis "
                "tools for crypto crime detection."
            ),
            "technologies": [
                "Python",
                "Blockchain Analytics",
                "Data Engineering",
                "Kubernetes",
                "Google Cloud Platform",
                "Regulatory Compliance",
                "Risk Management",
                "Cryptocurrency Security",
            ],
            "type": "engineering",
            "icon": "fas fa-shield-alt",
        },
        {
            "title": "Member Technical Staff",
            "company": "Redcarpetup",
            "period": "May. 2019 – Apr. 2021",
            "location": "Delhi, India",
            "company_url": "https://www.ycombinator.com/companies/redcarpetup",
            "logo": "/static/img/logos/redcarpetup.png",
            "description": (
                "Core engineering team member at Y Combinator-backed fintech "
                "startup. Built scalable lending platform infrastructure, "
                "implemented risk assessment algorithms, and developed "
                "customer-facing financial products."
            ),
            "technologies": [
                "Python",
                "Django Framework",
                "PostgreSQL",
                "Redis",
                "AWS Cloud",
                "Machine Learning",
                "Financial Technology",
                "REST APIs",
                "Microservices Architecture",
            ],
            "type": "engineering",
            "icon": "fas fa-chart-line",
        },
        {
            "title": "Co-Founder & Chief Technology Officer",
            "company": "Techneith",
            "period": "Oct. 2017 – Apr. 2019",
            "location": "Delhi, India",
            "company_url": "https://techneith.com/",
            "logo": "/static/img/logos/techneith.png",
            "description": (
                "Co-founded technology consulting company, leading technical vision "
                "and team building. Delivered end-to-end software solutions for "
                "startups and enterprises while establishing engineering best "
                "practices and company culture."
            ),
            "technologies": [
                "Full-Stack Engineering",
                "Team Leadership",
                "Strategic Planning",
                "Client Relations",
                "System Architecture",
                "Startup Operations",
            ],
            "type": "leadership",
            "icon": "fas fa-users",
        },
    ]

    # Education data from CV
    education = [
        {
            "degree": "Master of Business Administration (Management)",
            "institution": "Estonian Business School",
            "period": "June 2024",
            "location": "Tallinn, Estonia",
            "gpa": "GPA 4.44/5",
            "institution_url": "https://ebs.ee",
            "logo": "/static/img/logos/ebs.png",
            "description": (
                "Completed comprehensive MBA program focusing on strategic "
                "management, digital transformation, and entrepreneurship. "
                "Achieved distinction with 4.44/5 GPA while building "
                "international business network."
            ),
            "focus": [
                "Strategic Management",
                "Digital Transformation",
                "Entrepreneurship",
                "International Business",
            ],
            "type": "masters",
            "icon": "fas fa-graduation-cap",
        },
        {
            "degree": "Erasmus Exchange (Business Analytics and Financial Modeling)",
            "institution": "Norwegian School of Economics",
            "period": "December 2023",
            "location": "Bergen, Norway",
            "gpa": None,
            "institution_url": "https://nhh.no",
            "logo": "/static/img/logos/nhh.png",
            "description": (
                "Intensive exchange program at Norway's leading business school, "
                "specializing in advanced business analytics and quantitative "
                "financial modeling techniques for strategic decision making."
            ),
            "focus": [
                "Business Analytics",
                "Financial Modeling",
                "Data Science",
                "Quantitative Analysis",
            ],
            "type": "exchange",
            "icon": "fas fa-chart-bar",
        },
        {
            "degree": "Bachelor of Technology (Computer Science and Engineering)",
            "institution": "Deenbandhu Chottu Ram University of Science and Technology",
            "period": "September 2017",
            "location": "Haryana, India",
            "gpa": None,
            "institution_url": "https://dcrustm.ac.in",
            "logo": "/static/img/logos/dcrust.png",
            "description": (
                "Comprehensive engineering program covering software development, "
                "algorithms, data structures, and system design. Built strong "
                "foundation in computer science principles and practical "
                "programming skills."
            ),
            "focus": [
                "Software Engineering",
                "Data Structures",
                "Algorithms",
                "System Design",
                "Programming",
            ],
            "type": "bachelors",
            "icon": "fas fa-code",
        },
    ]

    return templates.TemplateResponse(
        request,
        "timeline.html",
        {
            "title": "Timeline - Tony",
            "active_page": "timeline",
            "work_experience": work_experience,
            "education": education,
        },
    )


@home.get("/terminal")
@limiter.limit("30/minute")
async def terminal_page(request: Request):
    """Full-page terminal interface."""
    return templates.TemplateResponse(
        request,
        "terminal.html",
        {"title": "Terminal - Tony", "active_page": "terminal"},
    )


@home.post("/contact")
@limiter.limit("5/minute")
async def contact_submit(
    request: Request,
    name: str = Form(..., min_length=2, max_length=100),
    email: str = Form(..., min_length=5, max_length=255),
    subject: str = Form(..., min_length=5, max_length=200),
    message: str = Form(..., min_length=10, max_length=2000),
):
    """Handle contact form submission."""
    settings = get_settings()

    try:
        # Create email message
        msg = MIMEMultipart()
        msg["From"] = (
            settings.smtp_username
            if hasattr(settings, "smtp_username") and settings.smtp_username
            else "noreply@tonybenoy.com"
        )
        msg["To"] = (
            settings.contact_email
            if hasattr(settings, "contact_email")
            else "me@tonybenoy.com"
        )
        msg["Subject"] = f"Contact Form: {subject}"

        # Email body
        body = f"""
New contact form submission:

From: {name} <{email}>
Subject: {subject}

Message:
{message}

---
Sent from tonybenoy.com contact form
Client IP: {request.client.host if request.client else "unknown"}
User Agent: {request.headers.get("User-Agent", "unknown")}
        """

        msg.attach(MIMEText(body, "plain"))

        # Send email (only if SMTP is configured)
        if hasattr(settings, "smtp_server") and settings.smtp_server:
            try:
                smtp_port = (
                    settings.smtp_port if hasattr(settings, "smtp_port") else 587
                )
                server = smtplib.SMTP(settings.smtp_server, smtp_port)
                server.starttls()
                if (
                    hasattr(settings, "smtp_username")
                    and hasattr(settings, "smtp_password")
                    and settings.smtp_username
                    and settings.smtp_password
                ):
                    server.login(settings.smtp_username, settings.smtp_password)

                server.send_message(msg)
                server.quit()

                logger.info(f"Contact form email sent from {email}")
                success_message = "Thank you! Your message has been sent successfully."
            except Exception as e:
                logger.error(f"Failed to send email: {e}")
                success_message = (
                    "Thank you! Your message has been received "
                    "(email delivery pending)."
                )
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
                "success_message": success_message,
            },
        )

    except Exception as e:
        logger.error(f"Contact form error: {e}")
        return templates.TemplateResponse(
            request,
            "contact.html",
            {
                "title": "Contact - Tony",
                "active_page": "contact",
                "error_message": (
                    "Sorry, there was an error sending your message. Please try again."
                ),
            },
        )
