import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from fastapi import APIRouter, Form, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.responses import RedirectResponse

from app.config import get_settings
from app.utils import get_structured_data, templates

# Use the same limiter instance as main app
limiter = Limiter(key_func=get_remote_address)

logger = logging.getLogger(__name__)
home = APIRouter()


@home.get("/")
@home.get("/index")
@limiter.limit("30/minute")
async def index(request: Request):
    """Home page with rate limiting and SEO optimization."""
    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "title": "Tony Benoy — CTO, Builder, Jugaadu",
            "description": (
                "CTO at Proffyhub, founder of Sunyata, previously Merkle Science "
                "and Redcarpetup (YC). Building things for the web from Tallinn, "
                "Estonia. Python enthusiast, Rust curious, MBA from Estonian "
                "Business School."
            ),
            "active_page": "home",
            "structured_data": get_structured_data(),
        },
    )


@home.get("/test")
async def test():
    return {"result": "It works!"}


@home.get("/favicon.ico")
async def favicon():
    return RedirectResponse(url="/static/img/favicon.ico")


@home.get("/robots.txt")
async def robots():
    """Serve robots.txt for SEO."""
    return RedirectResponse(url="/static/robots.txt")


@home.get("/sitemap.xml")
async def sitemap():
    """Serve sitemap.xml for SEO."""
    return RedirectResponse(url="/static/sitemap.xml")


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
        request,
        "contact.html",
        {
            "title": "Contact — Tony Benoy",
            "description": (
                "Send Tony a message or find him on LinkedIn, Twitter, and "
                "GitHub. Open to interesting conversations about tech, "
                "startups, or collaboration."
            ),
            "active_page": "contact",
        },
    )


@home.get("/timeline")
@limiter.limit("30/minute")
async def timeline_page(request: Request):
    """Timeline page with work experience and education."""
    # Work experience data
    work_experience = [
        {
            "title": "Co-Founder & Chief Technology Officer",
            "company": "Proffyhub OÜ",
            "period": "Jul. 2024 – Present",
            "location": "Tallinn, Estonia",
            "company_url": "https://proffy.ee",
            "logo": "/static/img/logos/proffyhub.png",
            "description": (
                "Took over as CTO to rebuild Proffy.ee from the ground up — "
                "an Estonian marketplace that matches employers with flexible "
                "workers. Hired the engineering team, chose the stack, and "
                "shipped the platform from zero to production. Day-to-day "
                "is a mix of architecture decisions, code reviews, and making "
                "sure the product actually solves the problem it claims to."
            ),
            "technologies": [
                "TypeScript",
                "NestJS",
                "PostgreSQL",
                "Next.js",
                "React",
                "AWS",
                "LLMs",
                "Tool-Call Agents",
            ],
            "type": "leadership",
            "icon": "crown",
        },
        {
            "title": "Founder",
            "company": "Sunyata OÜ",
            "period": "Nov. 2022 – Present",
            "location": "Tallinn, Estonia",
            "company_url": "https://github.com/Sunyata-OU",
            "logo": "/static/img/logos/sunyata.png",
            "description": (
                "My own company in Estonia — part consulting vehicle, part "
                "playground for building things I find interesting. Lets me "
                "take on projects that excite me and contribute to open source "
                "without asking anyone for permission."
            ),
            "technologies": [
                "Python",
                "Rust",
                "FastAPI",
                "Docker",
                "CI/CD",
            ],
            "type": "entrepreneurship",
            "icon": "rocket",
        },
        {
            "title": "Senior Software Engineer",
            "company": "Merkle Science",
            "period": "Aug. 2021 – Apr. 2022",
            "location": "Bengaluru, India",
            "company_url": "https://merklescience.com",
            "logo": "/static/img/logos/merkle-science.png",
            "description": (
                "Built tools that help banks and regulators figure out who's "
                "doing what on the blockchain. Worked on transaction risk "
                "scoring, entity resolution across chains, and data pipelines "
                "that could handle the firehose of on-chain activity. Left "
                "to move to Estonia for my MBA."
            ),
            "technologies": [
                "Python",
                "Kubernetes",
                "GCP",
                "BigQuery",
                "Redis",
                "Celery",
            ],
            "type": "engineering",
            "icon": "shield",
        },
        {
            "title": "Engineering Manager",
            "company": "Redcarpetup",
            "period": "May. 2019 – Apr. 2021",
            "location": "Delhi, India",
            "company_url": "https://www.ycombinator.com/companies/redcarpetup",
            "logo": "/static/img/logos/redcarpetup.png",
            "description": (
                "Early engineer at a YC-backed fintech building credit products "
                "for underserved borrowers in India. Built the lending platform, "
                "risk scoring engine, and the internal tools the ops team lived "
                "in. Learned what it means to ship when it actually matters — "
                "people's money was on the line."
            ),
            "technologies": [
                "Python",
                "Django",
                "PostgreSQL",
                "Redis",
                "AWS",
                "Celery",
                "REST APIs",
            ],
            "type": "engineering",
            "icon": "chart-line",
        },
        {
            "title": "Co-Founder & CTO",
            "company": "Techneith",
            "period": "Oct. 2017 – Apr. 2019",
            "location": "Delhi, India",
            "company_url": "https://techneith.com/",
            "logo": "/static/img/logos/techneith.png",
            "description": (
                "First real venture — co-founded a dev shop right out of "
                "college. We built software for startups and small businesses, "
                "figured out how to hire and manage a team, and learned every "
                "lesson about running a company the hard way. Eventually moved "
                "on, but it shaped how I think about building things."
            ),
            "technologies": [
                "Python",
                "Django",
                "React",
                "Node.js",
                "AWS",
                "PostgreSQL",
            ],
            "type": "leadership",
            "icon": "users",
        },
    ]

    # Education data
    education = [
        {
            "degree": "MBA in Management",
            "institution": "Estonian Business School",
            "period": "June 2024",
            "location": "Tallinn, Estonia",
            "gpa": "GPA 4.44/5",
            "institution_url": "https://ebs.ee",
            "logo": "/static/img/logos/ebs.png",
            "description": (
                "Went back to school after 5 years of building companies and "
                "writing code. Wanted the business vocabulary to match the "
                "technical instincts. Focused on strategy and digital "
                "transformation — basically learning to talk about what I "
                "was already doing, but better."
            ),
            "focus": [
                "Strategy",
                "Digital Transformation",
                "Entrepreneurship",
                "Finance",
            ],
            "type": "masters",
            "icon": "graduation-cap",
        },
        {
            "degree": "Erasmus Exchange — Business Analytics",
            "institution": "Norwegian School of Economics (NHH)",
            "period": "December 2023",
            "location": "Bergen, Norway",
            "gpa": None,
            "institution_url": "https://nhh.no",
            "logo": "/static/img/logos/nhh.png",
            "description": (
                "Semester abroad at one of the top business schools in the "
                "Nordics. Deep dive into financial modeling and data-driven "
                "decision making. Also discovered that Bergen has more rain "
                "than any city should be allowed."
            ),
            "focus": [
                "Financial Modeling",
                "Business Analytics",
                "Data Science",
            ],
            "type": "exchange",
            "icon": "chart-column",
        },
        {
            "degree": "B.Tech in Computer Science",
            "institution": "DCRUST",
            "period": "September 2017",
            "location": "Haryana, India",
            "gpa": None,
            "institution_url": "https://dcrustm.ac.in",
            "logo": "/static/img/logos/dcrust.png",
            "description": (
                "Where it all started. Algorithms, data structures, OS internals "
                "— the usual CS curriculum. But most of the real learning "
                "happened outside class: contributing to open source, building "
                "side projects, and breaking things on my Arch Linux install."
            ),
            "focus": [
                "Algorithms",
                "Data Structures",
                "OS & Systems",
                "Networking",
            ],
            "type": "bachelors",
            "icon": "code",
        },
    ]

    volunteer = [
        {
            "role": "AUR Package Maintainer",
            "org": "Arch Linux",
            "period": "2017 – 2024 (7 years)",
            "icon": "linux",
            "color": "vol-blue",
        },
        {
            "role": "PyPI Package Author",
            "org": "cocapi — Clash of Clans API wrapper",
            "period": "2018 – Present",
            "icon": "python",
            "color": "vol-orange",
        },
        {
            "role": "Open Source Contributor",
            "org": "Various Python & Rust projects",
            "period": "2017 – Present",
            "icon": "git-branch",
            "color": "vol-cyan",
        },
    ]

    return templates.TemplateResponse(
        request,
        "timeline.html",
        {
            "title": "Timeline — Tony Benoy",
            "description": (
                "From Delhi to Tallinn — CTO at Proffyhub, co-founded "
                "Techneith, built fintech at Redcarpetup (YC), blockchain "
                "analytics at Merkle Science. MBA from Estonian Business "
                "School, B.Tech from DCRUST. 7 years maintaining Arch Linux "
                "packages."
            ),
            "active_page": "timeline",
            "work_experience": work_experience,
            "education": education,
            "volunteer": volunteer,
        },
    )


@home.get("/terminal")
@limiter.limit("30/minute")
async def terminal_page(request: Request):
    """Full-page terminal interface."""
    return templates.TemplateResponse(
        request,
        "terminal.html",
        {
            "title": "Terminal — Tony Benoy",
            "description": (
                "An interactive browser terminal on Tony Benoy's website. "
                "Run commands like whoami, ls, skills, and more. Navigate "
                "the site, check the time, or find easter eggs."
            ),
            "active_page": "terminal",
        },
    )


@home.get("/chat")
@limiter.limit("30/minute")
async def chat_page(request: Request):
    """AI chat page with in-browser LLM."""
    return templates.TemplateResponse(
        request,
        "chat.html",
        {
            "title": "Tony's AI — Tony Benoy",
            "description": (
                "Because every website needs AI now. A small language model "
                "runs entirely in your browser via WebGPU — no servers, no "
                "API keys, no data leaves your machine. Ask it about Tony "
                "or just chat."
            ),
            "active_page": "chat",
        },
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
